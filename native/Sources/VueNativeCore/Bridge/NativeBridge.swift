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

            // Register __VN_log for debug logging from JS
            let log: @convention(block) (JSValue) -> Void = { message in
                NSLog("[VueNative JS] \(message.toString() ?? "")")
            }
            context.setObject(log, forKeyedSubscript: "__VN_log" as NSString)
        }
    }

    // MARK: - Operation Processing

    /// Process a batch of operations on the main thread.
    /// Each operation has an "op" key and "args" array.
    private func processOperations(_ operations: [[String: Any]]) {
        dispatchPrecondition(condition: .onQueue(.main))
        NSLog("[VueNative Bridge] Processing %d operations", operations.count)

        for operation in operations {
            guard let op = operation["op"] as? String,
                  let args = operation["args"] as? [Any] else {
                NSLog("[VueNative Bridge] Warning: Invalid operation format: \(operation)")
                continue
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
            default:
                NSLog("[VueNative Bridge] Warning: Unknown operation '\(op)'")
            }
        }

        // After processing all operations, trigger layout recalculation
        triggerLayout()
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

        // For scroll views, children go into the inner content view
        let container = childContainer(for: parentView)
        container.addSubview(childView)
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

        let container = childContainer(for: parentView)
        if let index = container.subviews.firstIndex(of: beforeView) {
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

        childView.removeFromSuperview()
        viewRegistry.removeValue(forKey: childId)
        typeRegistry.removeValue(forKey: childId)

        // Clean up any event handlers for this node
        let prefix = "\(childId):"
        eventHandlers = eventHandlers.filter { !$0.key.hasPrefix(prefix) }
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

        // Schedule an initial layout pass after the constraints are resolved
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()

        // Perform FlexLayout on next run loop to ensure frame is set
        DispatchQueue.main.async { [weak self] in
            self?.triggerLayout()
        }
    }

    // MARK: - Layout

    /// Trigger a FlexLayout relayout on the root view, then update any scroll views.
    /// Called after processing each operation batch.
    private func triggerLayout() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let rootView = rootView else { return }

        // FlexLayout computes layout based on the root view's bounds
        let bounds = rootView.bounds
        NSLog("[VueNative Bridge] triggerLayout() rootView bounds: %.1f x %.1f", bounds.width, bounds.height)
        if bounds.width > 0 && bounds.height > 0 {
            rootView.flex.layout()
            // After the main layout pass, recompute content sizes for all scroll views
            updateScrollViewContentSizes()
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

    // MARK: - View Registry Access (for testing/debugging)

    /// Get a view from the registry by node ID. Must be called on main thread.
    public func view(forNodeId nodeId: Int) -> UIView? {
        dispatchPrecondition(condition: .onQueue(.main))
        return viewRegistry[nodeId]
    }

    /// Get the total number of registered views.
    public var registeredViewCount: Int {
        return viewRegistry.count
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
            self.rootView = nil
        }
    }

    // MARK: - Helpers

    /// Safely convert a JSON value to Int.
    /// JSON numbers may come as Int, Double, or NSNumber.
    private func asInt(_ value: Any) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        if let n = value as? NSNumber { return n.intValue }
        return nil
    }
}
#endif
