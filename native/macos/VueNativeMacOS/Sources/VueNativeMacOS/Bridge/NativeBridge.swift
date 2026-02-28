import JavaScriptCore
import AppKit
import VueNativeShared

/// The main bridge between JavaScript and native AppKit.
///
/// Responsibilities:
/// - Registers `__VN_flushOperations` on JSContext to receive batched ops from JS
/// - Parses operation batches (JSON) and processes them on the main thread
/// - Maintains `viewRegistry` mapping node IDs to native NSViews
/// - Triggers layout relayout after processing each batch
/// - Dispatches native events back to JS via `dispatchEventToJS`
///
/// Thread safety:
/// - `__VN_flushOperations` is called on the JS queue
/// - JSON parsing happens on the JS queue
/// - All NSView operations dispatch to main thread
/// - `viewRegistry` is only accessed on the main thread
/// - `eventHandlers` is only accessed on the main thread
@MainActor
public final class NativeBridge: @preconcurrency NativeEventDispatcher {

    // MARK: - Singleton

    public static let shared = NativeBridge()

    // MARK: - Properties

    /// Maps node IDs to their native NSViews. Accessed only on main thread.
    private var viewRegistry: [Int: NSView] = [:]

    /// Maps node IDs to their component type strings. Accessed only on main thread.
    private var typeRegistry: [Int: String] = [:]

    /// Maps (nodeId, eventName) to event handler closures. Accessed only on main thread.
    private var eventHandlers: [String: (Any?) -> Void] = [:]

    /// Reverse index: maps nodeId to the set of event handler keys for that node.
    private var eventKeysPerNode: [Int: Set<String>] = [:]

    /// Maps each child node ID to its parent node ID.
    private var nodeParent: [Int: Int] = [:]

    /// Reverse index: maps parent node ID to an ordered list of child node IDs.
    private var childrenOf: [Int: [Int]] = [:]

    /// The root NSView that contains all rendered native views.
    private weak var rootView: NSView?

    /// The window's content view that hosts everything.
    private weak var contentView: NSView?

    /// The component registry for creating views and handling props/events.
    private let registry = ComponentRegistry.shared

    /// Reference to the JS runtime.
    private let runtime = JSRuntime.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Bridge Function Registration

    /// Register `__VN_flushOperations`, `__VN_teardown`, `__VN_log`, and `__VN_handleError`
    /// on the given JSContext.
    private func registerBridgeFunctions(on context: JSContext) {
        let flushOps: @convention(block) (JSValue) -> Void = { [weak self] opsValue in
            guard let self = self else { return }
            guard let jsonString = opsValue.toString(), !jsonString.isEmpty else {
                NSLog("[VueNative macOS Bridge] Warning: Empty operations batch")
                return
            }

            guard let data = jsonString.data(using: .utf8),
                  let operations = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                NSLog("[VueNative macOS Bridge] Error: Failed to parse operations JSON")
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.processOperations(operations)
            }
        }
        context.setObject(flushOps, forKeyedSubscript: "__VN_flushOperations" as NSString)

        let teardown: @convention(block) () -> Void = { [weak self] in
            NSLog("[VueNative macOS] Teardown called from JS")
            _ = self
        }
        context.setObject(teardown, forKeyedSubscript: "__VN_teardown" as NSString)

        let log: @convention(block) (JSValue) -> Void = { message in
            NSLog("[VueNative macOS JS] \(message.toString() ?? "")")
        }
        context.setObject(log, forKeyedSubscript: "__VN_log" as NSString)

        let handleError: @convention(block) (JSValue) -> Void = { errorInfoValue in
            let jsonString = errorInfoValue.toString() ?? "{}"
            NSLog("[VueNative macOS Error] %@", jsonString)

            if let data = jsonString.data(using: .utf8),
               let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let message = info["message"] as? String ?? "Unknown error"
                let stack = info["stack"] as? String ?? ""
                let componentName = info["componentName"] as? String ?? "unknown"
                NSLog("[VueNative macOS Error] Component: %@, Message: %@", componentName, message)
                if !stack.isEmpty {
                    NSLog("[VueNative macOS Error] Stack: %@", stack)
                }
            }
        }
        context.setObject(handleError, forKeyedSubscript: "__VN_handleError" as NSString)
    }

    // MARK: - Setup

    /// Initialize the bridge. Must be called after JSRuntime.initialize().
    public func initialize(contentView: NSView) {
        self.contentView = contentView

        let runtime = self.runtime

        runtime.jsQueue.async { [weak self] in
            guard let self = self, let context = runtime.context else { return }
            self.registerBridgeFunctions(on: context)
        }

        // Register all native modules, passing self as event dispatcher and
        // a view lookup closure for modules that need to reference views (e.g. Animation).
        NativeModuleRegistry.shared.registerDefaults(
            dispatcher: self,
            viewLookup: { [weak self] nodeId in self?.view(forId: nodeId) }
        )
    }

    // MARK: - Operation Processing

    private static let treeMutationOps: Set<String> = [
        "create", "createText", "appendChild", "insertBefore", "removeChild",
        "setRootView", "setText", "setElementText"
    ]

    private static let layoutAffectingStyles: Set<String> = [
        "width", "height", "minWidth", "minHeight", "maxWidth", "maxHeight",
        "flex", "flexGrow", "flexShrink", "flexBasis", "flexDirection",
        "flexWrap", "alignItems", "alignSelf", "alignContent", "justifyContent",
        "padding", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
        "paddingHorizontal", "paddingVertical", "paddingStart", "paddingEnd",
        "margin", "marginTop", "marginRight", "marginBottom", "marginLeft",
        "marginHorizontal", "marginVertical", "marginStart", "marginEnd",
        "gap", "rowGap", "columnGap",
        "position", "top", "right", "bottom", "left", "start", "end",
        "aspectRatio", "display", "overflow", "direction",
    ]

    func processOperations(_ operations: [[String: Any]]) {
        dispatchPrecondition(condition: .onQueue(.main))
        #if DEBUG
        NSLog("[VueNative macOS Bridge] Processing %d operations", operations.count)
        #endif

        var needsLayout = false

        for operation in operations {
            guard let op = operation["op"] as? String,
                  let args = operation["args"] as? [Any] else {
                NSLog("[VueNative macOS Bridge] Warning: Invalid operation format: \(operation)")
                continue
            }

            if !needsLayout && NativeBridge.treeMutationOps.contains(op) {
                needsLayout = true
            }

            if !needsLayout && op == "updateStyle",
               args.count >= 2,
               let styles = args[1] as? [String: Any] {
                for key in styles.keys {
                    if NativeBridge.layoutAffectingStyles.contains(key) {
                        needsLayout = true
                        break
                    }
                }
            }

            switch op {
            case "create":
                handleCreate(args: args)
            case "createText":
                handleCreateText(args: args)
            case "setText":
                handleSetText(args: args)
            case "setElementText":
                handleSetElementText(args: args)
            case "updateProp":
                handleUpdateProp(args: args)
            case "updateStyle":
                handleUpdateStyle(args: args)
            case "appendChild":
                handleAppendChild(args: args)
            case "insertBefore":
                handleInsertBefore(args: args)
            case "removeChild":
                handleRemoveChild(args: args)
            case "addEventListener":
                handleAddEventListener(args: args)
            case "removeEventListener":
                handleRemoveEventListener(args: args)
            case "setRootView":
                handleSetRootView(args: args)
            case "invokeNativeModule":
                handleInvokeNativeModule(args: args)
            case "invokeNativeModuleSync":
                handleInvokeNativeModuleSync(args: args)
            default:
                NSLog("[VueNative macOS Bridge] Warning: Unknown operation '\(op)'")
            }
        }

        if needsLayout {
            triggerLayout()
        }
    }

    // MARK: - Operation Handlers

    /// create: [nodeId: Int, type: String]
    private func handleCreate(args: [Any]) {
        guard args.count >= 2,
              let nodeId = asInt(args[0]),
              let type = args[1] as? String else {
            NSLog("[VueNative macOS Bridge] Error: Invalid create args: \(args)")
            return
        }

        guard let view = registry.createView(type: type) else {
            NSLog("[VueNative macOS Bridge] Error: Failed to create view for type '\(type)'")
            return
        }

        viewRegistry[nodeId] = view
        typeRegistry[nodeId] = type
    }

    /// createText: [nodeId: Int, text: String]
    private func handleCreateText(args: [Any]) {
        guard args.count >= 2,
              let nodeId = asInt(args[0]),
              let text = args[1] as? String else {
            NSLog("[VueNative macOS Bridge] Error: Invalid createText args: \(args)")
            return
        }

        guard let view = registry.createView(type: "VText") else { return }

        if let textField = view as? NSTextField {
            textField.stringValue = text
            textField.ensureLayoutNode().markDirty()
        }

        viewRegistry[nodeId] = view
        typeRegistry[nodeId] = "VText"
    }

    /// setText: [nodeId: Int, text: String]
    private func handleSetText(args: [Any]) {
        guard args.count >= 2,
              let nodeId = asInt(args[0]),
              let text = args[1] as? String else {
            return
        }

        guard let view = viewRegistry[nodeId] else { return }

        if let textField = view as? NSTextField {
            textField.stringValue = text
            textField.ensureLayoutNode().markDirty()
        }
    }

    /// setElementText: [nodeId: Int, text: String]
    private func handleSetElementText(args: [Any]) {
        guard args.count >= 2,
              let nodeId = asInt(args[0]),
              let text = args[1] as? String else {
            return
        }

        guard let view = viewRegistry[nodeId] else { return }

        if let textField = view as? NSTextField {
            textField.stringValue = text
            textField.ensureLayoutNode().markDirty()
        } else {
            if let existingTextField = view.subviews.first(where: { $0 is NSTextField }) as? NSTextField {
                existingTextField.stringValue = text
                existingTextField.ensureLayoutNode().markDirty()
            }
        }
    }

    /// updateProp: [nodeId: Int, key: String, value: Any?]
    private func handleUpdateProp(args: [Any]) {
        guard args.count >= 3,
              let nodeId = asInt(args[0]),
              let key = args[1] as? String else {
            return
        }

        guard let view = viewRegistry[nodeId] else { return }
        let value: Any? = (args[2] is NSNull) ? nil : args[2]
        registry.updateProp(view: view, key: key, value: value)
    }

    /// updateStyle: [nodeId: Int, styles: [String: Any]]
    private func handleUpdateStyle(args: [Any]) {
        guard args.count >= 2,
              let nodeId = asInt(args[0]),
              let styles = args[1] as? [String: Any] else {
            return
        }

        guard let view = viewRegistry[nodeId] else { return }

        for (key, value) in styles {
            let resolvedValue: Any? = (value is NSNull) ? nil : value
            if let type = typeRegistry[nodeId], let factory = registry.factory(for: type) {
                factory.updateProp(view: view, key: key, value: resolvedValue)
            } else {
                StyleEngine.apply(key: key, value: resolvedValue, to: view)
            }
        }
    }

    /// appendChild: [parentId: Int, childId: Int]
    private func handleAppendChild(args: [Any]) {
        guard args.count >= 2,
              let parentId = asInt(args[0]),
              let childId = asInt(args[1]) else {
            return
        }

        guard let parentView = viewRegistry[parentId],
              let childView = viewRegistry[childId] else {
            return
        }

        nodeParent[childId] = parentId
        childrenOf[parentId, default: []].append(childId)

        let container = childContainer(for: parentView)
        if let factory = ComponentRegistry.factory(for: parentView) {
            factory.insertChild(childView, into: container, before: nil)
        } else {
            container.addSubview(childView)
        }
    }

    /// insertBefore: [parentId: Int, childId: Int, beforeId: Int]
    private func handleInsertBefore(args: [Any]) {
        guard args.count >= 3,
              let parentId = asInt(args[0]),
              let childId = asInt(args[1]),
              let beforeId = asInt(args[2]) else {
            return
        }

        guard let parentView = viewRegistry[parentId],
              let childView = viewRegistry[childId],
              let beforeView = viewRegistry[beforeId] else {
            return
        }

        nodeParent[childId] = parentId
        var siblings = childrenOf[parentId, default: []]
        if let idx = siblings.firstIndex(of: beforeId) {
            siblings.insert(childId, at: idx)
        } else {
            siblings.append(childId)
        }
        childrenOf[parentId] = siblings

        let container = childContainer(for: parentView)
        if let factory = ComponentRegistry.factory(for: parentView) {
            factory.insertChild(childView, into: container, before: beforeView)
        } else if let subviews = container.subviews as? [NSView],
                  let index = subviews.firstIndex(of: beforeView) {
            container.addSubview(childView, positioned: .below, relativeTo: beforeView)
        } else {
            container.addSubview(childView)
        }
    }

    /// Returns the view that children should be inserted into.
    private func childContainer(for view: NSView) -> NSView {
        // For scroll views, children go into the documentView.
        if let scrollView = view as? NSScrollView,
           let docView = scrollView.documentView {
            return docView
        }
        return view
    }

    /// removeChild: [childId: Int]
    private func handleRemoveChild(args: [Any]) {
        guard args.count >= 1,
              let childId = asInt(args[0]) else {
            return
        }

        guard let childView = viewRegistry[childId] else { return }

        removeDescendantsFromIndex(childId)

        if let parentId = nodeParent[childId],
           let parentView = viewRegistry[parentId],
           let factory = ComponentRegistry.factory(for: parentView) {
            let container = childContainer(for: parentView)
            factory.removeChild(childView, from: container)
        } else {
            childView.removeFromSuperview()
        }

        if let parentId = nodeParent[childId] {
            childrenOf[parentId]?.removeAll { $0 == childId }
        }

        cleanupNodeRegistries(childId)
    }

    private func cleanupNodeRegistries(_ nodeId: Int) {
        nodeParent.removeValue(forKey: nodeId)
        viewRegistry.removeValue(forKey: nodeId)
        typeRegistry.removeValue(forKey: nodeId)
        childrenOf.removeValue(forKey: nodeId)

        if let keys = eventKeysPerNode.removeValue(forKey: nodeId) {
            for key in keys {
                eventHandlers.removeValue(forKey: key)
            }
        }
    }

    private func removeDescendantsFromIndex(_ nodeId: Int) {
        guard let children = childrenOf[nodeId] else { return }
        for childId in children {
            removeDescendantsFromIndex(childId)
            cleanupNodeRegistries(childId)
        }
    }

    /// addEventListener: [nodeId: Int, eventName: String, callbackId: Int]
    private func handleAddEventListener(args: [Any]) {
        guard args.count >= 2,
              let nodeId = asInt(args[0]),
              let eventName = args[1] as? String else {
            return
        }

        guard let view = viewRegistry[nodeId] else { return }

        let handlerKey = "\(nodeId):\(eventName)"

        let handler: (Any?) -> Void = { [weak self] payload in
            self?.dispatchEventToJS(nodeId: nodeId, eventName: eventName, payload: payload)
        }

        eventHandlers[handlerKey] = handler
        eventKeysPerNode[nodeId, default: []].insert(handlerKey)

        registry.addEventListener(view: view, event: eventName, handler: handler)
    }

    /// removeEventListener: [nodeId: Int, eventName: String]
    private func handleRemoveEventListener(args: [Any]) {
        guard args.count >= 2,
              let nodeId = asInt(args[0]),
              let eventName = args[1] as? String else {
            return
        }

        let handlerKey = "\(nodeId):\(eventName)"
        eventHandlers.removeValue(forKey: handlerKey)
        eventKeysPerNode[nodeId]?.remove(handlerKey)

        if let view = viewRegistry[nodeId] {
            registry.removeEventListener(view: view, event: eventName)
        }
    }

    /// setRootView: [nodeId: Int]
    private func handleSetRootView(args: [Any]) {
        guard args.count >= 1,
              let nodeId = asInt(args[0]) else {
            return
        }

        NSLog("[VueNative macOS Bridge] handleSetRootView called with nodeId=%d", nodeId)

        guard let view = viewRegistry[nodeId] else {
            NSLog("[VueNative macOS Bridge] Error: Root view \(nodeId) not found in registry")
            return
        }

        guard let contentView = contentView else {
            NSLog("[VueNative macOS Bridge] Error: No content view set")
            return
        }

        NSLog("[VueNative macOS Bridge] Setting up root view, contentView bounds: %.1f x %.1f", contentView.bounds.width, contentView.bounds.height)

        rootView = view
        view.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(view)

        // Pin root view to content view edges
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentView.topAnchor),
            view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        contentView.needsLayout = true
        contentView.layoutSubtreeIfNeeded()

        DispatchQueue.main.async { [weak self] in
            self?.triggerLayoutWithRetries(remaining: 3)
        }

        // Monitor dark mode changes
        setupAppearanceObserver()
    }

    /// Set up observation for dark mode (effective appearance) changes.
    private func setupAppearanceObserver() {
        // On macOS, observe NSApp.effectiveAppearance via KVO
        // or use DistributedNotificationCenter for theme changes.
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            self?.dispatchGlobalEvent("colorScheme:change", payload: ["colorScheme": isDark ? "dark" : "light"])
        }
    }

    // MARK: - Native Module Handlers

    private func handleInvokeNativeModule(args: [Any]) {
        guard args.count >= 4,
              let moduleName = args[0] as? String,
              let methodName = args[1] as? String,
              let moduleArgs = args[2] as? [Any],
              let callbackId = asInt(args[3]) else {
            NSLog("[VueNative macOS Bridge] Error: Invalid invokeNativeModule args: \(args)")
            return
        }

        NativeModuleRegistry.shared.invoke(
            module: moduleName,
            method: methodName,
            args: moduleArgs
        ) { [weak self] result, error in
            self?.resolveNativeCallback(callbackId: callbackId, result: result, error: error)
        }
    }

    private func handleInvokeNativeModuleSync(args: [Any]) {
        guard args.count >= 3,
              let moduleName = args[0] as? String,
              let methodName = args[1] as? String,
              let moduleArgs = args[2] as? [Any] else {
            NSLog("[VueNative macOS Bridge] Error: Invalid invokeNativeModuleSync args: \(args)")
            return
        }

        _ = NativeModuleRegistry.shared.invokeSync(
            module: moduleName,
            method: methodName,
            args: moduleArgs
        )
    }

    private func resolveNativeCallback(callbackId: Int, result: Any?, error: String?) {
        let safeResult: Any = result ?? NSNull()
        let safeError: Any = error ?? NSNull()
        runtime.callFunction("__VN_resolveCallback", withArguments: [callbackId, safeResult, safeError])
    }

    // MARK: - Layout

    /// Trigger layout on the root view using the LayoutNode system.
    private func triggerLayout() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let rootView = rootView else { return }

        rootView.layoutSubtreeIfNeeded()

        let bounds = rootView.bounds
        NSLog("[VueNative macOS Bridge] triggerLayout() rootView bounds: %.1f x %.1f", bounds.width, bounds.height)

        guard bounds.width > 0 && bounds.height > 0 else {
            NSLog("[VueNative macOS Bridge] triggerLayout() skipped: bounds not yet resolved")
            return
        }

        // Run layout using the LayoutNode system
        if let layoutNode = rootView.layoutNode {
            layoutNode.layout(availableWidth: bounds.width, availableHeight: bounds.height)
        }
    }

    private func triggerLayoutWithRetries(remaining: Int) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let rootView = rootView else { return }

        rootView.layoutSubtreeIfNeeded()
        let bounds = rootView.bounds

        if bounds.width > 0 && bounds.height > 0 {
            triggerLayout()
        } else if remaining > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.triggerLayoutWithRetries(remaining: remaining - 1)
            }
        } else {
            NSLog("[VueNative macOS Bridge] triggerLayoutWithRetries exhausted -- root view bounds still zero")
        }
    }

    // MARK: - Event Dispatch to JS

    /// Dispatch a native event to the JS side.
    public func dispatchEventToJS(nodeId: Int, eventName: String, payload: Any?) {
        let safePayload: Any
        if let payload = payload {
            if JSONSerialization.isValidJSONObject(["v": payload]) {
                safePayload = payload
            } else if let str = payload as? String {
                safePayload = str
            } else if let num = payload as? NSNumber {
                safePayload = num
            } else {
                safePayload = NSNull()
            }
        } else {
            safePayload = NSNull()
        }

        runtime.callFunction("__VN_handleEvent", withArguments: [nodeId, eventName, safePayload])
    }

    /// Dispatch a global event to the JS side (not tied to any specific node).
    public func dispatchGlobalEvent(_ eventName: String, payload: [String: Any] = [:]) {
        let payloadJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let str = String(data: data, encoding: .utf8) {
            payloadJSON = str
        } else {
            payloadJSON = "{}"
        }

        runtime.callFunction("__VN_handleGlobalEvent", withArguments: [eventName, payloadJSON])
    }

    // MARK: - View Registry Access

    /// Get a view from the registry by node ID. Must be called on main thread.
    public func view(forNodeId nodeId: Int) -> NSView? {
        dispatchPrecondition(condition: .onQueue(.main))
        return viewRegistry[nodeId]
    }

    func view(forId id: Int) -> NSView? {
        return viewRegistry[id]
    }

    public var registeredViewCount: Int {
        return viewRegistry.count
    }

    // MARK: - Hot Reload

    /// Reload the app with a new JavaScript bundle string.
    public func reloadWithBundle(_ bundle: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        NSLog("[VueNative macOS Bridge] reloadWithBundle: calling __VN_teardown on old context...")

        runtime.jsQueue.sync {
            if let context = runtime.context,
               let teardown = context.objectForKeyedSubscript("__VN_teardown"),
               !teardown.isUndefined {
                teardown.call(withArguments: [])
                context.evaluateScript("void 0;")
            }
        }

        NSLog("[VueNative macOS Bridge] reloadWithBundle: clearing view hierarchy...")

        for (_, view) in viewRegistry {
            view.removeFromSuperview()
        }
        viewRegistry.removeAll()
        typeRegistry.removeAll()
        eventHandlers.removeAll()
        eventKeysPerNode.removeAll()
        nodeParent.removeAll()
        childrenOf.removeAll()

        runtime.reload(bundle: bundle) { [weak self] success in
            guard let self = self else { return }
            guard success else {
                NSLog("[VueNative macOS Bridge] reloadWithBundle: runtime reload failed")
                ErrorOverlayView.show(error: "Hot reload failed.\n\nThe new bundle could not be evaluated. Check the terminal for the JS error.\n\nSave the file again to retry.")
                return
            }

            guard let context = self.runtime.context else { return }
            self.registerBridgeFunctions(on: context)

            NSLog("[VueNative macOS Bridge] reloadWithBundle: bridge re-registered on new context")
        }
    }

    // MARK: - Cleanup

    public func reset() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for (_, view) in self.viewRegistry {
                view.removeFromSuperview()
            }
            self.viewRegistry.removeAll()
            self.typeRegistry.removeAll()
            self.eventHandlers.removeAll()
            self.eventKeysPerNode.removeAll()
            self.nodeParent.removeAll()
            self.childrenOf.removeAll()
            self.rootView = nil
        }
    }

    // MARK: - Helpers

    private func asInt(_ value: Any) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double {
            guard d.isFinite, d >= Double(Int.min), d <= Double(Int.max) else { return nil }
            return Int(d)
        }
        if let n = value as? NSNumber { return n.intValue }
        return nil
    }
}
