import AppKit

/// Protocol that all native component factories must implement.
/// Each factory knows how to create an NSView, update its properties,
/// and wire up event listeners for a specific component type.
@MainActor
protocol NativeComponentFactory {

    /// Create a new NSView instance for this component type.
    /// The view should be configured with sensible defaults and a LayoutNode.
    func createView() -> NSView

    /// Update a property on the view. The key is the property name from JS,
    /// and value is the property value (nil means the prop was removed).
    func updateProp(view: NSView, key: String, value: Any?)

    /// Add an event listener to the view. The handler closure will dispatch
    /// the event payload back to the JS thread.
    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void)

    /// Remove an event listener from the view for the given event name.
    /// Default implementation is a no-op.
    func removeEventListener(view: NSView, event: String)

    /// Insert a child view into the parent. Called by the bridge instead of addSubview.
    /// Default implementation calls parent.addSubview(child) with optional anchor positioning.
    func insertChild(_ child: NSView, into parent: NSView, before anchor: NSView?)

    /// Remove a child view from the parent. Called by the bridge instead of removeFromSuperview.
    /// Default implementation calls child.removeFromSuperview().
    func removeChild(_ child: NSView, from parent: NSView)
}

// Default implementation for optional methods
extension NativeComponentFactory {
    func removeEventListener(view: NSView, event: String) {
        // Default no-op. Factories can override to clean up specific listeners.
    }

    func insertChild(_ child: NSView, into parent: NSView, before anchor: NSView?) {
        if let anchor = anchor, let idx = parent.subviews.firstIndex(of: anchor) {
            // NSView uses addSubview(_:positioned:relativeTo:) for ordering.
            // .below places the child just before the anchor in the subview array.
            parent.addSubview(child, positioned: .below, relativeTo: anchor)
        } else {
            parent.addSubview(child)
        }
        child.ensureLayoutNode()
    }

    func removeChild(_ child: NSView, from parent: NSView) {
        child.removeFromSuperview()
    }
}
