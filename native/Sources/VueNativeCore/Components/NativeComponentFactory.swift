#if canImport(UIKit)
import UIKit

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
}

// Default implementation for optional methods
extension NativeComponentFactory {
    func removeEventListener(view: UIView, event: String) {
        // Default no-op. Factories can override to clean up specific listeners.
    }
}
#endif
