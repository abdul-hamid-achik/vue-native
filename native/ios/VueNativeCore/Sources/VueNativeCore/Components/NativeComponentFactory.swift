#if canImport(UIKit)
import UIKit
import FlexLayout

/// Protocol that all native component factories must implement.
/// Each factory knows how to create a UIView, update its properties,
/// and wire up event listeners for a specific component type.
@MainActor
protocol NativeComponentFactory {

    /// Create a new UIView instance for this component type.
    /// The view should be configured with sensible defaults and FlexLayout enabled.
    func createView() -> UIView

    /// Update a property on the view. The key is the property name from JS,
    /// and value is the property value (nil means the prop was removed).
    func updateProp(view: UIView, key: String, value: Any?)

    /// Add an event listener to the view. The handler closure will dispatch
    /// the event payload back to the JS thread.
    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void)

    /// Remove an event listener from the view for the given event name.
    /// Default implementation is a no-op.
    func removeEventListener(view: UIView, event: String)

    /// Insert a child view into the parent. Called by the bridge instead of addSubview.
    /// Default implementation calls parent.addSubview(child) or insertSubview(at:) with anchor.
    func insertChild(_ child: UIView, into parent: UIView, before anchor: UIView?)

    /// Remove a child view from the parent. Called by the bridge instead of removeFromSuperview.
    /// Default implementation calls child.removeFromSuperview().
    func removeChild(_ child: UIView, from parent: UIView)
}

// Default implementation for optional methods
extension NativeComponentFactory {
    func removeEventListener(view: UIView, event: String) {
        // Default no-op. Factories can override to clean up specific listeners.
    }

    func insertChild(_ child: UIView, into parent: UIView, before anchor: UIView?) {
        if let anchor = anchor, let idx = parent.subviews.firstIndex(of: anchor) {
            parent.flex.addItem(child)
            // Move to correct position after adding
            parent.insertSubview(child, at: idx)
        } else {
            parent.flex.addItem(child)
        }
    }

    func removeChild(_ child: UIView, from parent: UIView) {
        child.removeFromSuperview()
    }
}
#endif
