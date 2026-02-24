#if canImport(UIKit)
import JavaScriptCore
import UIKit
import FlexLayout

/// The main bridge between JavaScript and native UIKit.
///
/// Responsibilities:
/// - Registers `__VN_flushOperations` on JSContext to receive batched ops from JS
/// - Parses operation batches (JSON) and processes them on the main thread
/// - Maintains `viewRegistry` mapping node IDs to native UIViews
/// - Triggers FlexLayout relayout after processing each batch
/// - Dispatches native events back to JS via `dispatchEventToJS`
///
/// Thread safety:
/// - `__VN_flushOperations` is called on the JS queue
/// - JSON parsing happens on the JS queue
/// - All UIView operations dispatch to main thread
/// - `viewRegistry` is only accessed on the main thread
/// - `eventHandlers` is only accessed on the main thread
@MainActor
public final class NativeBridge {

    // MARK: - Singleton

    public static let shared = NativeBridge()

    // MARK: - Properties

    /// Maps node IDs to their native UIViews. Accessed only on main thread.
    private var viewRegistry: [Int: UIView] = [:]

    /// Maps node IDs to their component type strings. Accessed only on main thread.
    private var typeRegistry: [Int: String] = [:]

    /// Maps (nodeId, eventName) to event handler closures. Accessed only on main thread.
    /// The handlers dispatch the event payload back to the JS queue.
    private var eventHandlers: [String: (Any?) -> Void] = [:]

    /// Reverse index: maps nodeId to the set of event handler keys for that node.
    /// Provides O(1) cleanup instead of O(n) scan of eventHandlers on removal.
    private var eventKeysPerNode: [Int: Set<String>] = [:]

    /// Maps each child node ID to its parent node ID.
    /// Used to look up the parent factory when removing a child.
    private var nodeParent: [Int: Int] = [:]

    /// Reverse index: maps parent node ID to an ordered list of child node IDs.
    /// Provides O(1) children lookup instead of O(n) scan of nodeParent.
    private var childrenOf: [Int: [Int]] = [:]

    /// The root UIView that contains all rendered native views.
    private weak var rootView: UIView?

    /// Reference to the root view controller for safe area calculations.
    private weak var rootViewController: UIViewController?

    /// The component registry for creating views and handling props/events.
    private let registry = ComponentRegistry.shared

    /// Reference to the JS runtime.
    private let runtime = JSRuntime.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Trait Observer Key

    private static var traitObserverKey: UInt8 = 99

    // MARK: - Setup

    /// Initialize the bridge. Must be called after JSRuntime.initialize().
    /// Registers the `__VN_flushOperations` and `__VN_handleEvent` functions on JSContext.
    public func initialize(rootViewController: UIViewController) {
        self.rootViewController = rootViewController

        let runtime = self.runtime

        // Register __VN_flushOperations on the JS context.
        // This is called from JS with a JSON string of batched operations.
        runtime.jsQueue.async { [weak self] in
            guard let self = self, let context = runtime.context else { return }

            let flushOps: @convention(block) (JSValue) -> Void = { [weak self] opsValue in
                guard let self = self else { return }
                guard let jsonString = opsValue.toString(), !jsonString.isEmpty else {
                    NSLog("[VueNative Bridge] Warning: Empty operations batch")
                    return
                }

                // Parse JSON on the JS queue (avoid main thread work)
                guard let data = jsonString.data(using: .utf8),
                      let operations = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    NSLog("[VueNative Bridge] Error: Failed to parse operations JSON")
                    return
                }

                // Process operations on the main thread
                DispatchQueue.main.async { [weak self] in
                    self?.processOperations(operations)
                }
            }
            context.setObject(flushOps, forKeyedSubscript: "__VN_flushOperations" as NSString)

            // Register __VN_teardown for graceful JS-side shutdown on hot reload
            let teardown: @convention(block) () -> Void = { [weak self] in
                // Graceful shutdown: bridge will be re-initialized on reload
                NSLog("[VueNative] Teardown called from JS")
                _ = self
            }
            context.setObject(teardown, forKeyedSubscript: "__VN_teardown" as NSString)

            // Register __VN_log for debug logging from JS
            let log: @convention(block) (JSValue) -> Void = { message in
                NSLog("[VueNative JS] \(message.toString() ?? "")")
            }
            context.setObject(log, forKeyedSubscript: "__VN_log" as NSString)

            // Register __VN_handleError for JS error reporting
            // Called from JS with a JSON-encoded string containing error info
            // (message, stack, componentName).
            let handleError: @convention(block) (JSValue) -> Void = { errorInfoValue in
                let jsonString = errorInfoValue.toString() ?? "{}"
                NSLog("[VueNative Error] %@", jsonString)

                // Try to extract structured fields for clearer logging
                if let data = jsonString.data(using: .utf8),
                   let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let message = info["message"] as? String ?? "Unknown error"
                    let stack = info["stack"] as? String ?? ""
                    let componentName = info["componentName"] as? String ?? "unknown"
                    NSLog("[VueNative Error] Component: %@, Message: %@", componentName, message)
                    if !stack.isEmpty {
                        NSLog("[VueNative Error] Stack: %@", stack)
                    }
                }
            }
            context.setObject(handleError, forKeyedSubscript: "__VN_handleError" as NSString)
        }

        // Register all native modules synchronously so they are available
        // before any JS bundle evaluation that may invoke them.
        NativeModuleRegistry.shared.registerDefaults()
    }

    // MARK: - Operation Processing

    /// Operations that mutate the view tree structure and require a layout pass.
    private static let treeMutationOps: Set<String> = [
        "create", "createText", "appendChild", "insertBefore", "removeChild",
        "setRootView", "setText", "setElementText"
    ]

    /// Process a batch of operations on the main thread.
    /// Each operation has an "op" key and "args" array.
    /// Only triggers a Yoga layout pass when the batch contains tree mutations
    /// (create, appendChild, insertBefore, removeChild, etc.). Batches that
    /// only update props/styles/events skip the expensive layout recalculation.
    private func processOperations(_ operations: [[String: Any]]) {
        dispatchPrecondition(condition: .onQueue(.main))
        NSLog("[VueNative Bridge] Processing %d operations", operations.count)

        var hasMutations = false

        for operation in operations {
            guard let op = operation["op"] as? String,
                  let args = operation["args"] as? [Any] else {
                NSLog("[VueNative Bridge] Warning: Invalid operation format: \(operation)")
                continue
            }

            if !hasMutations && NativeBridge.treeMutationOps.contains(op) {
                hasMutations = true
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
                NSLog("[VueNative Bridge] Warning: Unknown operation '\(op)'")
            }
        }

        // Only trigger layout recalculation when the batch mutated the view tree
        if hasMutations {
            triggerLayout()
        }
    }

    // MARK: - Operation Handlers

    /// create: [nodeId: Int, type: String]
    private func handleCreate(args: [Any]) {
        guard args.count >= 2,
              let nodeId = asInt(args[0]),
              let type = args[1] as? String else {
            NSLog("[VueNative Bridge] Error: Invalid create args: \(args)")
            return
        }

        guard let view = registry.createView(type: type) else {
            NSLog("[VueNative Bridge] Error: Failed to create view for type '\(type)'")
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
            NSLog("[VueNative Bridge] Error: Invalid createText args: \(args)")
            return
        }

        // Text nodes are rendered as UILabels
        guard let view = registry.createView(type: "VText") else { return }

        if let label = view as? UILabel {
            label.text = text
            label.flex.markDirty()
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

        if let label = view as? UILabel {
            label.text = text
            label.flex.markDirty()
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

        if let label = view as? UILabel {
            label.text = text
            label.flex.markDirty()
        } else {
            // For non-label views, find the first UILabel child and set text
            // or create a new text label as a child
            if let existingLabel = view.subviews.first(where: { $0 is UILabel }) as? UILabel {
                existingLabel.text = text
                existingLabel.flex.markDirty()
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

        // The value might be NSNull for nil
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
            // Try factory-specific prop handling first
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
        // For scroll views, children go into the inner content view
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
        // Insert into childrenOf at the correct position (before beforeId)
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
        } else if let index = container.subviews.firstIndex(of: beforeView) {
            container.insertSubview(childView, at: index)
        } else {
            container.addSubview(childView)
        }
    }

    /// Returns the view that children should be inserted into.
    /// For UIScrollView, this is the inner content view; for all others it is the view itself.
    private func childContainer(for view: UIView) -> UIView {
        if let scrollView = view as? UIScrollView,
           let contentView = VScrollViewFactory.contentView(for: scrollView) {
            return contentView
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

        // Recursively clean up all descendant nodes using the childrenOf index
        removeDescendantsFromIndex(childId)

        // Look up parent factory for custom removal
        if let parentId = nodeParent[childId],
           let parentView = viewRegistry[parentId],
           let factory = ComponentRegistry.factory(for: parentView) {
            let container = childContainer(for: parentView)
            factory.removeChild(childView, from: container)
        } else {
            childView.removeFromSuperview()
        }

        // Remove child from parent's childrenOf list
        if let parentId = nodeParent[childId] {
            childrenOf[parentId]?.removeAll { $0 == childId }
        }

        cleanupNodeRegistries(childId)
    }

    /// Clean up all registry entries for a single node ID.
    /// Uses the eventKeysPerNode index for O(1) event handler cleanup.
    private func cleanupNodeRegistries(_ nodeId: Int) {
        nodeParent.removeValue(forKey: nodeId)
        viewRegistry.removeValue(forKey: nodeId)
        typeRegistry.removeValue(forKey: nodeId)
        childrenOf.removeValue(forKey: nodeId)

        // O(k) cleanup where k = number of handlers on this node, not O(total handlers)
        if let keys = eventKeysPerNode.removeValue(forKey: nodeId) {
            for key in keys {
                eventHandlers.removeValue(forKey: key)
            }
        }
    }

    /// Recursively clean up all descendant nodes using the childrenOf reverse index.
    /// This is O(n) in the subtree size rather than scanning the entire nodeParent dict.
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

        // Create a handler that dispatches the event back to JS
        let handler: (Any?) -> Void = { [weak self] payload in
            self?.dispatchEventToJS(nodeId: nodeId, eventName: eventName, payload: payload)
        }

        eventHandlers[handlerKey] = handler
        eventKeysPerNode[nodeId, default: []].insert(handlerKey)

        // Wire up the native event via the component's factory
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

        NSLog("[VueNative Bridge] handleSetRootView called with nodeId=%d", nodeId)

        guard let view = viewRegistry[nodeId] else {
            NSLog("[VueNative Bridge] Error: Root view \(nodeId) not found in registry")
            return
        }

        guard let vc = rootViewController else {
            NSLog("[VueNative Bridge] Error: No root view controller set")
            return
        }

        NSLog("[VueNative Bridge] Setting up root view, vc.view bounds: %.1f x %.1f", vc.view.bounds.width, vc.view.bounds.height)

        rootView = view
        view.translatesAutoresizingMaskIntoConstraints = false

        // Add root view to the view controller's view
        vc.view.addSubview(view)

        // Pin root view to safe area
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor),
            view.leadingAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor),
        ])

        // Force AutoLayout to resolve the root view's frame immediately.
        // This ensures rootView.bounds is non-zero before the Yoga layout pass.
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()

        // Perform FlexLayout on the next run loop tick.
        // By then AutoLayout has fully resolved all frames including safe area insets.
        // We also retry once more after 100 ms to handle edge cases where the window
        // has not yet been presented (e.g., first launch before viewDidAppear).
        DispatchQueue.main.async { [weak self] in
            self?.triggerLayout()
            // Second pass for cases where the first pass still sees zero bounds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.triggerLayout()
            }
        }

        // Monitor trait changes (dark mode) via a lightweight observer view
        let traitObserver = TraitObserverView()
        traitObserver.onChange = { [weak self] isDark in
            self?.dispatchGlobalEvent("colorScheme:change", payload: ["colorScheme": isDark ? "dark" : "light"])
        }
        traitObserver.isHidden = true
        vc.view.addSubview(traitObserver)
        // Retain the observer for the lifetime of the root view controller's view
        objc_setAssociatedObject(vc.view as UIView, &NativeBridge.traitObserverKey, traitObserver as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - Native Module Handlers

    /// invokeNativeModule: [moduleName: String, methodName: String, args: [Any], callbackId: Int]
    private func handleInvokeNativeModule(args: [Any]) {
        guard args.count >= 4,
              let moduleName = args[0] as? String,
              let methodName = args[1] as? String,
              let moduleArgs = args[2] as? [Any],
              let callbackId = asInt(args[3]) else {
            NSLog("[VueNative Bridge] Error: Invalid invokeNativeModule args: \(args)")
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

    /// invokeNativeModuleSync: [moduleName: String, methodName: String, args: [Any]]
    private func handleInvokeNativeModuleSync(args: [Any]) {
        guard args.count >= 3,
              let moduleName = args[0] as? String,
              let methodName = args[1] as? String,
              let moduleArgs = args[2] as? [Any] else {
            NSLog("[VueNative Bridge] Error: Invalid invokeNativeModuleSync args: \(args)")
            return
        }

        _ = NativeModuleRegistry.shared.invokeSync(
            module: moduleName,
            method: methodName,
            args: moduleArgs
        )
    }

    /// Resolve a native module callback by calling __VN_resolveCallback on the JS side.
    private func resolveNativeCallback(callbackId: Int, result: Any?, error: String?) {
        let safeResult: Any = result ?? NSNull()
        let safeError: Any = error ?? NSNull()
        runtime.callFunction("__VN_resolveCallback", withArguments: [callbackId, safeResult, safeError])
    }

    // MARK: - Layout

    /// Trigger a FlexLayout relayout on the root view, then update any scroll views.
    /// Called after processing each operation batch.
    ///
    /// Uses `layout(mode: .fitContainer)` so that Yoga fills the root view's current
    /// AutoLayout-resolved bounds rather than computing a size from scratch.
    /// `pointScaleFactor` is set from UIScreen.main.scale so text and border measurements
    /// are pixel-perfect on both 2x and 3x displays.
    private func triggerLayout() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let rootView = rootView else { return }

        // Ensure AutoLayout has resolved the frame before Yoga runs.
        rootView.layoutIfNeeded()

        let bounds = rootView.bounds
        NSLog("[VueNative Bridge] triggerLayout() rootView bounds: %.1f x %.1f", bounds.width, bounds.height)

        guard bounds.width > 0 && bounds.height > 0 else {
            // Bounds not yet resolved — schedule a retry.
            NSLog("[VueNative Bridge] triggerLayout() skipped: bounds not yet resolved")
            return
        }

        // Note: pointScaleFactor is already set to UIScreen.main.scale by FlexLayout's
        // YogaKit layer during globalConfig initialisation (YGLayout.mm line 179).
        // No manual override is needed here.

        // layout(mode: .fitContainer) instructs Yoga to use rootView.bounds as the
        // available space rather than computing it from children, matching CSS behaviour.
        rootView.flex.layout(mode: .fitContainer)

        // After the main layout pass, recompute content sizes for all scroll views.
        updateScrollViewContentSizes()
    }

    /// After the main layout pass, iterate registered scroll views and update their contentSize.
    private func updateScrollViewContentSizes() {
        for (_, view) in viewRegistry {
            if let scrollView = view as? UIScrollView {
                VScrollViewFactory.layoutContentView(for: scrollView)
            }
        }
    }

    // MARK: - Event Dispatch to JS

    /// Dispatch a native event to the JS side.
    /// Extracts primitive data from payload, then calls the JS handler on the JS queue.
    public func dispatchEventToJS(nodeId: Int, eventName: String, payload: Any?) {
        // Serialize payload to a JSON-safe value
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
    /// Safe to call from any thread — dispatches to the JS queue internally.
    /// JS must register a handler via `__VN_handleGlobalEvent(eventName, payloadJSON)`.
    public func dispatchGlobalEvent(_ eventName: String, payload: [String: Any] = [:]) {
        // Serialize payload dict to JSON string on whatever thread we're on
        let payloadJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let str = String(data: data, encoding: .utf8) {
            payloadJSON = str
        } else {
            payloadJSON = "{}"
        }

        runtime.callFunction("__VN_handleGlobalEvent", withArguments: [eventName, payloadJSON])
    }

    // MARK: - View Registry Access (for testing/debugging)

    /// Get a view from the registry by node ID. Must be called on main thread.
    public func view(forNodeId nodeId: Int) -> UIView? {
        dispatchPrecondition(condition: .onQueue(.main))
        return viewRegistry[nodeId]
    }

    /// Returns the UIView registered for the given node ID, or nil if not found.
    func view(forId id: Int) -> UIView? {
        return viewRegistry[id]
    }

    /// Get the total number of registered views.
    public var registeredViewCount: Int {
        return viewRegistry.count
    }

    // MARK: - Hot Reload

    /// Reload the app with a new JavaScript bundle string.
    /// 1. Clears all views and registries on the main thread.
    /// 2. Re-registers bridge functions on the new JSContext.
    /// 3. Evaluates the new bundle via JSRuntime.reload(bundle:).
    public func reloadWithBundle(_ bundle: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        NSLog("[VueNative Bridge] reloadWithBundle: calling __VN_teardown on old context...")

        // Step 0: Call __VN_teardown on the old JS context so the Vue app can clean up
        // (cancel timers, remove listeners, unmount components) before we destroy state.
        // This is a synchronous dispatch to the JS queue to ensure teardown completes
        // before we clear the native registries.
        runtime.jsQueue.sync {
            if let context = runtime.context,
               let teardown = context.objectForKeyedSubscript("__VN_teardown"),
               !teardown.isUndefined {
                teardown.call(withArguments: [])
                // Drain microtasks so any cleanup promises resolve
                context.evaluateScript("void 0;")
            }
        }

        NSLog("[VueNative Bridge] reloadWithBundle: clearing view hierarchy...")

        // Step 1: Remove all subviews from root and clear registries on main thread
        for (_, view) in viewRegistry {
            view.removeFromSuperview()
        }
        viewRegistry.removeAll()
        typeRegistry.removeAll()
        eventHandlers.removeAll()
        eventKeysPerNode.removeAll()
        nodeParent.removeAll()
        childrenOf.removeAll()
        // Keep rootView reference and rootViewController — we re-use the same container

        // Step 2: Re-register bridge functions on the new JSContext after runtime reloads.
        // JSRuntime.reload creates a fresh JSContext, so we must re-register our Swift blocks.
        // We do this by scheduling on the JS queue after the reload completes.
        runtime.reload(bundle: bundle) { [weak self] success in
            guard let self = self else { return }
            guard success else {
                NSLog("[VueNative Bridge] reloadWithBundle: runtime reload failed — showing error overlay")
                ErrorOverlayView.show(error: "Hot reload failed.\n\nThe new bundle could not be evaluated. Check the terminal for the JS error.\n\nSave the file again to retry.")
                return
            }

            // Re-register __VN_flushOperations, __VN_teardown, __VN_log on new context
            guard let context = self.runtime.context else { return }

            let flushOps: @convention(block) (JSValue) -> Void = { [weak self] opsValue in
                guard let self = self else { return }
                guard let jsonString = opsValue.toString(), !jsonString.isEmpty else {
                    NSLog("[VueNative Bridge] Warning: Empty operations batch")
                    return
                }

                guard let data = jsonString.data(using: .utf8),
                      let operations = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    NSLog("[VueNative Bridge] Error: Failed to parse operations JSON")
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    self?.processOperations(operations)
                }
            }
            context.setObject(flushOps, forKeyedSubscript: "__VN_flushOperations" as NSString)

            let teardown: @convention(block) () -> Void = { [weak self] in
                NSLog("[VueNative] Teardown called from JS")
                _ = self
            }
            context.setObject(teardown, forKeyedSubscript: "__VN_teardown" as NSString)

            let log: @convention(block) (JSValue) -> Void = { message in
                NSLog("[VueNative JS] \(message.toString() ?? "")")
            }
            context.setObject(log, forKeyedSubscript: "__VN_log" as NSString)

            let handleError: @convention(block) (JSValue) -> Void = { errorInfoValue in
                let jsonString = errorInfoValue.toString() ?? "{}"
                NSLog("[VueNative Error] %@", jsonString)

                if let data = jsonString.data(using: .utf8),
                   let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let message = info["message"] as? String ?? "Unknown error"
                    let stack = info["stack"] as? String ?? ""
                    let componentName = info["componentName"] as? String ?? "unknown"
                    NSLog("[VueNative Error] Component: %@, Message: %@", componentName, message)
                    if !stack.isEmpty {
                        NSLog("[VueNative Error] Stack: %@", stack)
                    }
                }
            }
            context.setObject(handleError, forKeyedSubscript: "__VN_handleError" as NSString)

            NSLog("[VueNative Bridge] reloadWithBundle: bridge re-registered on new context")
        }
    }

    // MARK: - Memory Warning

    /// Handle a system memory warning by dispatching a global event to JS.
    /// Call this from your UIApplicationDelegate's `applicationDidReceiveMemoryWarning`
    /// or from `UIViewController.didReceiveMemoryWarning()`.
    public func handleMemoryWarning() {
        dispatchGlobalEvent("memory:warning")
    }

    // MARK: - Cleanup

    /// Remove all views and reset the bridge state.
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

    /// Safely convert a JSON value to Int.
    /// JSON numbers may come as Int, Double, or NSNumber.
    /// Guards against NaN and Infinity which would produce undefined behavior in Int().
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
// MARK: - TraitObserverView

private final class TraitObserverView: UIView {
    var onChange: ((Bool) -> Void)?

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            onChange?(traitCollection.userInterfaceStyle == .dark)
        }
    }
}


#endif
