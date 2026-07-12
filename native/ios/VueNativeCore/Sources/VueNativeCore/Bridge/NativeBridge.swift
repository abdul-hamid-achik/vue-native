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
    private var rootConstraints: [NSLayoutConstraint] = []
    private var modalConstraints: [NSLayoutConstraint] = []

    /// Reference to the root view controller for safe area calculations.
    private weak var rootViewController: UIViewController?
    private var activeHostID: UUID?

    /// The component registry for creating views and handling props/events.
    private let registry = ComponentRegistry.shared

    /// Reference to the JS runtime.
    private let runtime = JSRuntime.shared

    /// Identifies the native host / JavaScript world that owns asynchronous
    /// module callbacks. Host replacement, reset, and reload all advance this
    /// value before releasing old state so late completions cannot resolve a
    /// callback ID that has since been reused by a fresh JS context.
    private var nativeCallbackGeneration: UInt64 = 0

    // MARK: - Teleport Support

    /// Maps teleport marker IDs (start, end) for cleanup
    private var teleportMarkers: [Int: (start: Int, end: Int)] = [:]

    /// Maps parent node IDs to their teleport containers
    private var teleportContainers: [Int: UIView] = [:]

    /// Modal container for teleporting modals
    private lazy var modalContainer: UIView = {
        let container = UIView()
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = true
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }()

    // MARK: - Initialization

    private init() {}

    // MARK: - Trait Observer Key

    private static var traitObserverKey: UInt8 = 99

    // MARK: - Bridge Function Registration

    /// Register `__VN_flushOperations`, `__VN_teardown`, `__VN_log`, and `__VN_handleError`
    /// on the given JSContext. Called from both `initialize()` and `reloadWithBundle()`.
    nonisolated private func registerBridgeFunctions(on context: JSContext) {
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
    }

    // MARK: - Setup

    /// Initialize the bridge. Must be called after JSRuntime.initialize().
    /// Registers the `__VN_flushOperations` and `__VN_handleEvent` functions on JSContext.
    public func initialize(rootViewController: UIViewController, hostID: UUID? = nil) {
        prepareHost(rootViewController: rootViewController)
        activeHostID = hostID

        let runtime = self.runtime

        // Register __VN_flushOperations on the JS context.
        // This is called from JS with a JSON string of batched operations.
        runtime.jsQueue.async { [weak self] in
            guard let self = self, let context = runtime.context else { return }

            self.registerBridgeFunctions(on: context)
        }

        // Register all native modules synchronously so they are available
        // before any JS bundle evaluation that may invoke them.
        NativeModuleRegistry.shared.registerDefaults()
    }

    /// Install a native host, synchronously clearing state owned by a previous
    /// controller. Kept internal so SwiftPM tests can exercise host lifecycle
    /// without constructing notification modules that require an app test host.
    func prepareHost(rootViewController: UIViewController) {
        // NativeBridge is a singleton, while host view controllers may be
        // recreated (scene replacement, tests, or an embedding app swapping
        // controllers). Tear down the old host before replacing the weak
        // reference so clearRootConstraints() can remove its trait observer.
        if let currentHost = self.rootViewController,
           currentHost !== rootViewController {
            clearManagedViewState()
        }
        self.rootViewController = rootViewController
    }

    /// Release native state only when it still belongs to the closing host.
    /// An older controller may deinitialize after its replacement is active.
    @discardableResult
    func releaseHost(hostID: UUID) -> Bool {
        guard activeHostID == hostID else { return false }
        reset()
        rootViewController = nil
        activeHostID = nil
        return true
    }

    // MARK: - Operation Processing

    /// Operations that mutate the view tree structure and require a layout pass.
    private static let treeMutationOps: Set<String> = [
        "create", "createText", "appendChild", "insertBefore", "removeChild",
        "setRootView", "setText", "setElementText"
    ]

    /// Style properties that affect Yoga layout and require a layout pass when changed.
    /// When a batch contains only updateStyle ops for non-layout properties (e.g.
    /// backgroundColor, opacity), we skip the expensive layout recalculation.
    private static let layoutAffectingStyles: Set<String> = [
        // Dimensions
        "width", "height", "minWidth", "minHeight", "maxWidth", "maxHeight",
        // Flex
        "flex", "flexGrow", "flexShrink", "flexBasis", "flexDirection",
        "flexWrap", "alignItems", "alignSelf", "alignContent", "justifyContent",
        // Spacing
        "padding", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
        "paddingHorizontal", "paddingVertical", "paddingStart", "paddingEnd",
        "margin", "marginTop", "marginRight", "marginBottom", "marginLeft",
        "marginHorizontal", "marginVertical", "marginStart", "marginEnd",
        // Gap
        "gap", "rowGap", "columnGap",
        // Position
        "position", "top", "right", "bottom", "left", "start", "end",
        // Other layout
        "aspectRatio", "display", "overflow", "direction",
    ]

    /// Process a batch of operations on the main thread.
    /// Each operation has an "op" key and "args" array.
    /// Triggers a Yoga layout pass when the batch contains tree mutations
    /// (create, appendChild, insertBefore, removeChild, etc.) OR style changes
    /// that affect layout (width, height, padding, margin, flex, etc.).
    /// Batches that only update visual styles/events skip the expensive layout.
    ///
    /// Access: internal (not private) so that `@testable import` can exercise
    /// operation handling without going through JSContext.
    func processOperations(_ operations: [[String: Any]]) {
        dispatchPrecondition(condition: .onQueue(.main))
        #if DEBUG
        NSLog("[VueNative Bridge] Processing %d operations", operations.count)
        #endif

        var needsLayout = false

        for operation in operations {
            guard let op = operation["op"] as? String,
                  let args = operation["args"] as? [Any] else {
                NSLog("[VueNative Bridge] Warning: Invalid operation format: \(operation)")
                continue
            }

            if !needsLayout && NativeBridge.treeMutationOps.contains(op) {
                needsLayout = true
            }

            // Check if updateStyle changes any layout-affecting property
            if !needsLayout && op == "updateStyle",
               args.count >= 2,
               let styles = args[1] as? [String: Any] {
                for key in styles.keys where NativeBridge.layoutAffectingStyles.contains(key) {
                    needsLayout = true
                    break
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
            case "createTeleport":
                handleCreateTeleport(args: args)
            case "removeTeleport":
                handleRemoveTeleport(args: args)
            case "teleportTo":
                handleTeleportTo(args: args)
            case "invokeNativeModule":
                handleInvokeNativeModule(args: args)
            case "invokeNativeModuleSync":
                handleInvokeNativeModuleSync(args: args)
            default:
                NSLog("[VueNative Bridge] Warning: Unknown operation '\(op)'")
            }
        }

        // Trigger layout when tree was mutated or layout-affecting styles changed
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

        if let parentId = nodeParent[nodeId] {
            refreshTextHierarchy(startingAt: parentId)
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

        if let parentId = nodeParent[nodeId] {
            refreshTextHierarchy(startingAt: parentId)
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

        moveChild(childView, id: childId, to: parentView, parentId: parentId, before: nil)
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

        // Vue can emit an insert for an existing child to perform a keyed move.
        // Inserting a node before itself is already in the desired position.
        guard childId != beforeId else { return }

        moveChild(childView, id: childId, to: parentView, parentId: parentId, before: (beforeId, beforeView))
    }

    /// Move (or insert) a child while keeping the bridge's ownership indexes in
    /// sync with UIKit and custom containers such as VList/VText. UIKit's
    /// `addSubview` implicitly reparents ordinary views, but it cannot update
    /// the custom child arrays maintained by those factories. Detaching through
    /// the previous parent factory first prevents duplicate rows/text children
    /// and ensures removing the old parent cannot later destroy a moved child.
    private func moveChild(
        _ childView: UIView,
        id childId: Int,
        to parentView: UIView,
        parentId: Int,
        before anchor: (id: Int, view: UIView)?
    ) {
        detachChildForMove(childView, id: childId)

        var siblings = childrenOf[parentId, default: []]
        // A malformed/repeated operation must not create duplicate reverse
        // index entries. This also covers a same-parent keyed reorder.
        siblings.removeAll { $0 == childId }
        if let anchor, let index = siblings.firstIndex(of: anchor.id) {
            siblings.insert(childId, at: index)
        } else {
            siblings.append(childId)
        }
        childrenOf[parentId] = siblings
        nodeParent[childId] = parentId

        // For scroll views, children go into the inner content view.
        let container = childContainer(for: parentView)
        if let factory = ComponentRegistry.factory(for: parentView) {
            factory.insertChild(childView, into: container, before: anchor?.view)
        } else if let anchor = anchor,
                  let index = container.subviews.firstIndex(of: anchor.view) {
            container.insertSubview(childView, at: index)
            container.flex.markDirty()
            container.setNeedsLayout()
        } else {
            container.flex.addItem(childView)
        }

        refreshTextHierarchy(startingAt: parentId)
    }

    /// Remove a child from its previous native container and reverse index
    /// without unregistering the node. This is deliberately different from
    /// `handleRemoveChild`, which destroys a node and all of its descendants.
    private func detachChildForMove(_ childView: UIView, id childId: Int) {
        guard let oldParentId = nodeParent[childId] else { return }

        childrenOf[oldParentId]?.removeAll { $0 == childId }

        guard let oldParentView = viewRegistry[oldParentId] else {
            childView.removeFromSuperview()
            return
        }

        let oldContainer = childContainer(for: oldParentView)
        if let oldFactory = ComponentRegistry.factory(for: oldParentView) {
            oldFactory.removeChild(childView, from: oldContainer)
        } else {
            childView.removeFromSuperview()
        }

        refreshTextHierarchy(startingAt: oldParentId)
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
        let removingRoot = childView === rootView

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
            refreshTextHierarchy(startingAt: parentId)
        }

        cleanupNodeRegistries(childId)

        if removingRoot {
            clearRootConstraints()
            rootView = nil
        }
    }

    /// VText owns logical text-node children without adding them as visual
    /// subviews. When a text child changes, moves, or is removed, rebuild the
    /// owning label from the bridge's ordered child index and continue upward
    /// for nested VText elements.
    private func refreshTextHierarchy(startingAt nodeId: Int) {
        var currentId: Int? = nodeId

        while let id = currentId,
              typeRegistry[id] == "VText",
              let label = viewRegistry[id] as? UILabel {
            let text = childrenOf[id, default: []].compactMap { childId in
                (viewRegistry[childId] as? UILabel)?.text
            }.joined()
            label.text = text.isEmpty ? nil : text
            label.flex.markDirty()
            currentId = nodeParent[id]
        }
    }

    /// Clean up all registry entries for a single node ID.
    /// Uses the eventKeysPerNode index for O(1) event handler cleanup.
    private func cleanupNodeRegistries(_ nodeId: Int) {
        if let view = viewRegistry[nodeId] {
            if let keys = eventKeysPerNode[nodeId] {
                let prefix = "\(nodeId):"
                for key in keys where key.hasPrefix(prefix) {
                    registry.removeEventListener(
                        view: view,
                        event: String(key.dropFirst(prefix.count))
                    )
                }
            }
            registry.destroyView(view: view)
        }

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

        if let oldRoot = rootView, oldRoot !== view {
            oldRoot.removeFromSuperview()
        }
        clearRootConstraints()
        rootView = view
        view.translatesAutoresizingMaskIntoConstraints = false

        // Add root view to the view controller's view
        vc.view.addSubview(view)

        // Pin root view to safe area
        rootConstraints = [
            view.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor),
            view.leadingAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor),
        ]
        NSLayoutConstraint.activate(rootConstraints)

        // Force AutoLayout to resolve the root view's frame immediately.
        // This ensures rootView.bounds is non-zero before the Yoga layout pass.
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()

        // Perform FlexLayout on the next run loop tick.
        // By then AutoLayout has fully resolved all frames including safe area insets.
        // Retry up to 3 times with 100ms intervals to handle edge cases where the
        // window has not yet been presented (e.g., first launch before viewDidAppear).
        DispatchQueue.main.async { [weak self] in
            self?.triggerLayoutWithRetries(remaining: 3)
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

        installModalContainerIfNeeded()
    }

    // MARK: - Teleport Handlers

    /// createTeleport: [parentId: Int, startId: Int, endId: Int]
    private func handleCreateTeleport(args: [Any]) {
        guard args.count >= 3,
              let parentId = asInt(args[0]),
              let startId = asInt(args[1]),
              let endId = asInt(args[2]) else {
            NSLog("[VueNative Bridge] Error: Invalid createTeleport args: \(args)")
            return
        }

        guard let parentView = viewRegistry[parentId] else {
            NSLog("[VueNative Bridge] Error: Parent view not found for teleport (id: \(parentId))")
            return
        }

        // Store teleport marker IDs
        teleportMarkers[parentId] = (start: startId, end: endId)

        // Create container for teleported content
        let container = UIView()
        container.tag = -parentId  // Negative tag to identify as teleport container
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = true
        container.translatesAutoresizingMaskIntoConstraints = false

        parentView.addSubview(container)
        teleportContainers[parentId] = container

        #if DEBUG
        NSLog("[VueNative Bridge] Created teleport container for parent \(parentId)")
        #endif
    }

    /// removeTeleport: [parentId: Int, startId: Int, endId: Int]
    private func handleRemoveTeleport(args: [Any]) {
        guard args.count >= 1,
              let parentId = asInt(args[0]) else {
            NSLog("[VueNative Bridge] Error: Invalid removeTeleport args: \(args)")
            return
        }

        // Remove teleport container
        if let container = teleportContainers.removeValue(forKey: parentId) {
            container.removeFromSuperview()
        }

        // Clean up markers
        teleportMarkers.removeValue(forKey: parentId)

        #if DEBUG
        NSLog("[VueNative Bridge] Removed teleport container for parent \(parentId)")
        #endif
    }

    /// teleportTo: [target: String, nodeId: Int]
    private func handleTeleportTo(args: [Any]) {
        guard args.count >= 2,
              let target = args[0] as? String,
              let nodeId = asInt(args[1]) else {
            NSLog("[VueNative Bridge] Error: Invalid teleportTo args: \(args)")
            return
        }

        guard let targetView = getTeleportTarget(target) else {
            NSLog("[VueNative Bridge] Warning: Teleport target '\(target)' not found")
            return
        }

        guard let childView = viewRegistry[nodeId] else {
            NSLog("[VueNative Bridge] Warning: Node view not found for teleport (id: \(nodeId))")
            return
        }

        // Move view to teleport target
        childView.removeFromSuperview()
        targetView.addSubview(childView)

        // Set up full-size constraints
        childView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            childView.topAnchor.constraint(equalTo: targetView.topAnchor),
            childView.leadingAnchor.constraint(equalTo: targetView.leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: targetView.trailingAnchor),
            childView.bottomAnchor.constraint(equalTo: targetView.bottomAnchor),
        ])

        #if DEBUG
        NSLog("[VueNative Bridge] Teleported node \(nodeId) to target '\(target)'")
        #endif
    }

    /// Get teleport target view by name
    private func getTeleportTarget(_ target: String) -> UIView? {
        switch target {
        case "root":
            return rootView
        case "modal":
            installModalContainerIfNeeded()
            return modalContainer
        default:
            return nil
        }
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

        let originatingGeneration = nativeCallbackGeneration
        NativeModuleRegistry.shared.invoke(
            module: moduleName,
            method: methodName,
            args: moduleArgs
        ) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self,
                      self.nativeCallbackGeneration == originatingGeneration else {
                    return
                }
                self.resolveNativeCallback(callbackId: callbackId, result: result, error: error)
            }
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

    /// Attempt layout, retrying up to `remaining` times with 100ms delays if bounds are zero.
    /// Prevents unbounded retries when the root view never receives a valid frame.
    private func triggerLayoutWithRetries(remaining: Int) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let rootView = rootView else { return }

        rootView.layoutIfNeeded()
        let bounds = rootView.bounds

        if bounds.width > 0 && bounds.height > 0 {
            triggerLayout()
        } else if remaining > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.triggerLayoutWithRetries(remaining: remaining - 1)
            }
        } else {
            NSLog("[VueNative Bridge] triggerLayoutWithRetries exhausted — root view bounds still zero")
        }
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

        // Step 1: Remove all subviews and listeners from the old native tree.
        clearManagedViewState()
        // Keep rootViewController — the next bundle creates a fresh root view.

        // Step 2: JSRuntime.reload creates a fresh JSContext. Install bridge
        // functions before evaluating the new bundle so its initial render and
        // module calls cannot hit temporary polyfill stubs.
        runtime.reload(
            bundle: bundle,
            teardownOldContext: false,
            prepareContext: { [weak self] context in
                self?.registerBridgeFunctions(on: context)
            },
            completion: { success in
                guard success else {
                    NSLog("[VueNative Bridge] reloadWithBundle: runtime reload failed — showing error overlay")
                    DispatchQueue.main.async {
                        ErrorOverlayView.show(error: "Hot reload failed.\n\nThe new bundle could not be evaluated. Check the terminal for the JS error.\n\nSave the file again to retry.")
                    }
                    return
                }

                NSLog("[VueNative Bridge] reloadWithBundle: bridge re-registered on new context")
            }
        )
    }

    // MARK: - Memory Warning

    /// Handle a system memory warning by dispatching a global event to JS.
    /// Call this from your UIApplicationDelegate's `applicationDidReceiveMemoryWarning`
    /// or from `UIViewController.didReceiveMemoryWarning()`.
    public func handleMemoryWarning() {
        dispatchGlobalEvent("memory:warning")
    }

    // MARK: - Application Host Integration

    /// Seed the URL returned by `Linking.getInitialURL` before the JavaScript
    /// bundle starts. Call this from SceneDelegate/AppDelegate for a cold start.
    public func setInitialURL(_ url: URL?) {
        LinkingModule.initialURL = url?.absoluteString
    }

    /// Forward a URL received while the app is already running.
    public func handleOpenURL(_ url: URL) {
        dispatchGlobalEvent("url", payload: ["url": url.absoluteString])
    }

    /// Cache and forward an APNs device token. This public facade avoids host
    /// applications reaching into the framework's internal module registry.
    public func didRegisterForRemoteNotifications(deviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        NotificationsModule.cachedDeviceToken = token
        dispatchGlobalEvent("push:token", payload: ["token": token])
    }

    /// Forward a failed APNs registration attempt to JavaScript.
    public func didFailToRegisterForRemoteNotifications(error: Error) {
        dispatchGlobalEvent(
            "push:error",
            payload: ["message": error.localizedDescription]
        )
    }

    /// Normalize and forward an APNs payload delivered through UIApplicationDelegate.
    public func didReceiveRemoteNotification(userInfo: [AnyHashable: Any]) {
        let data = userInfo.reduce(into: [String: Any]()) { result, entry in
            guard let key = entry.key as? String else { return }
            result[key] = Self.jsonSafeNotificationValue(entry.value)
        }
        let aps = data["aps"] as? [String: Any] ?? [:]
        let alert = aps["alert"] as? [String: Any]
        let stringAlert = aps["alert"] as? String

        dispatchGlobalEvent(
            "push:received",
            payload: [
                "title": alert?["title"] as? String ?? "",
                "body": alert?["body"] as? String ?? stringAlert ?? "",
                "data": data,
                "remote": true,
            ]
        )
    }

    private static func jsonSafeNotificationValue(_ value: Any) -> Any {
        if let dictionary = value as? [AnyHashable: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, entry in
                guard let key = entry.key as? String else { return }
                result[key] = jsonSafeNotificationValue(entry.value)
            }
        }
        if let array = value as? [Any] {
            return array.map(jsonSafeNotificationValue)
        }
        if value is String || value is NSNumber || value is NSNull {
            return value
        }
        return String(describing: value)
    }

    // MARK: - Cleanup

    /// Remove all views and reset the bridge state.
    public func reset() {
        clearManagedViewState()
        NativeModuleRegistry.shared.removeAll()
    }

    /// Clear all state owned by the current native host. This is synchronous
    /// because callers are already isolated to the main actor and host
    /// replacement must finish before the new host reference is installed.
    private func clearManagedViewState() {
        nativeCallbackGeneration &+= 1

        for view in viewRegistry.values {
            view.removeFromSuperview()
        }
        for container in teleportContainers.values {
            container.removeFromSuperview()
        }
        clearRootConstraints()

        for nodeId in Array(viewRegistry.keys) {
            cleanupNodeRegistries(nodeId)
        }

        // Defensive clears cover malformed/incomplete trees whose reverse
        // indexes may not have matched the view registry.
        viewRegistry.removeAll()
        typeRegistry.removeAll()
        eventHandlers.removeAll()
        eventKeysPerNode.removeAll()
        nodeParent.removeAll()
        childrenOf.removeAll()
        teleportMarkers.removeAll()
        teleportContainers.removeAll()
        rootView = nil
    }

    private func installModalContainerIfNeeded() {
        guard let rootView, modalContainer.superview !== rootView else { return }
        modalContainer.removeFromSuperview()
        NSLayoutConstraint.deactivate(modalConstraints)
        modalConstraints.removeAll()
        rootView.addSubview(modalContainer)
        modalConstraints = [
            modalContainer.topAnchor.constraint(equalTo: rootView.topAnchor),
            modalContainer.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            modalContainer.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            modalContainer.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        ]
        NSLayoutConstraint.activate(modalConstraints)
    }

    private func clearRootConstraints() {
        NSLayoutConstraint.deactivate(rootConstraints)
        NSLayoutConstraint.deactivate(modalConstraints)
        rootConstraints.removeAll()
        modalConstraints.removeAll()
        modalContainer.removeFromSuperview()

        if let rootControllerView = rootViewController?.view,
           let traitObserver = objc_getAssociatedObject(
               rootControllerView,
               &NativeBridge.traitObserverKey
           ) as? TraitObserverView {
            traitObserver.onChange = nil
            traitObserver.removeFromSuperview()
            objc_setAssociatedObject(
                rootControllerView,
                &NativeBridge.traitObserverKey,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (view: TraitObserverView, _: UITraitCollection) in
                self?.onChange?(view.traitCollection.userInterfaceStyle == .dark)
            }
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // Fallback for iOS 16
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            onChange?(traitCollection.userInterfaceStyle == .dark)
        }
    }
}

#endif
