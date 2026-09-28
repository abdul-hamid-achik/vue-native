#if canImport(UIKit)
import UIKit
import FlexLayout

/// Protocol that all native component factories must implement.
/// Each factory knows how to create a UIView, update its properties,
/// and wire up event listeners for a specific component type.
///
/// Public so host applications can provide custom components via
/// ``VueNativeViewController/registerComponent(_:factory:)``.
@MainActor
public protocol NativeComponentFactory {

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

    /// Release resources owned by a view that is permanently leaving the
    /// native tree. Moves and reparenting do not call this method.
    /// Default implementation is a no-op.
    func destroyView(view: UIView)

    /// Insert a child view into the parent. Called by the bridge instead of addSubview.
    /// Default implementation calls parent.addSubview(child) or insertSubview(at:) with anchor.
    func insertChild(_ child: UIView, into parent: UIView, before anchor: UIView?)

    /// Remove a child view from the parent. Called by the bridge instead of removeFromSuperview.
    /// Default implementation calls child.removeFromSuperview().
    func removeChild(_ child: UIView, from parent: UIView)
}

// Default implementation for optional methods
extension NativeComponentFactory {
    public func removeEventListener(view: UIView, event: String) {
        // Default no-op. Factories can override to clean up specific listeners.
    }

    public func destroyView(view: UIView) {
        // Default no-op. Factories can override to release per-view resources.
    }

    public func insertChild(_ child: UIView, into parent: UIView, before anchor: UIView?) {
        if let anchor = anchor, let idx = parent.subviews.firstIndex(of: anchor) {
            parent.flex.addItem(child)
            // Move to correct position after adding
            parent.insertSubview(child, at: idx)
        } else {
            parent.flex.addItem(child)
        }
    }

    public func removeChild(_ child: UIView, from parent: UIView) {
        child.removeFromSuperview()
    }
}

// MARK: - VueNativeComponentSupport

/// Core services a ``NativeComponentFactory`` needs but cannot reach across a
/// module boundary: the built-in style router and the shared hex color parser.
///
/// This is what lets a factory live outside `VueNativeCore` — the optional
/// `VueNativeCoreSVG` product, or a host's own custom component — without
/// losing framework behaviour. Both are `internal` in core, so without this
/// wrapper an out-of-module factory would silently stop applying `width`,
/// `backgroundColor`, `borderRadius` and every other prop it does not handle
/// itself.
///
/// ```swift
/// func updateProp(view: UIView, key: String, value: Any?) {
///     switch key {
///     case "source": render(value, into: view)
///     default: VueNativeComponentSupport.applyStyle(key: key, value: value, to: view)
///     }
/// }
/// ```
@MainActor
public enum VueNativeComponentSupport {

    /// Apply a single built-in style prop to `view`.
    ///
    /// The same `StyleEngine.apply(key:value:to:)` entry point core factories
    /// fall through to for props they do not handle. Unknown keys are ignored,
    /// exactly as they are inside core.
    public static func applyStyle(key: String, value: Any?, to view: UIView) {
        StyleEngine.apply(key: key, value: value, to: view)
    }

    /// Parse a hex color string (`#rgb`, `#rrggbb`, `#rrggbbaa`, with or without
    /// the leading `#`) exactly as the built-in factories do. Returns `nil` for
    /// anything unparseable rather than falling back to a default color.
    public static func color(fromHex hex: String) -> UIColor? {
        UIColor.fromHex(hex)
    }
}
#endif
