import AppKit

/// Protocol that all native component factories must implement.
/// Each factory knows how to create an NSView, update its properties,
/// and wire up event listeners for a specific component type.
///
/// Public so apps can register custom components via
/// `VueNativeWindowController.registerComponent(_:factory:)`.
@MainActor
public protocol NativeComponentFactory {

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

    /// Release resources owned by a view that is permanently leaving the
    /// native tree. Moves and reparenting do not call this method.
    /// Default implementation is a no-op.
    func destroyView(view: NSView)

    /// Insert a child view into the parent. Called by the bridge instead of addSubview.
    /// Default implementation calls parent.addSubview(child) with optional anchor positioning.
    func insertChild(_ child: NSView, into parent: NSView, before anchor: NSView?)

    /// Remove a child view from the parent. Called by the bridge instead of removeFromSuperview.
    /// Default implementation calls child.removeFromSuperview().
    func removeChild(_ child: NSView, from parent: NSView)
}

// Default implementation for optional methods
public extension NativeComponentFactory {
    func removeEventListener(view: NSView, event: String) {
        // Default no-op. Factories can override to clean up specific listeners.
    }

    func destroyView(view: NSView) {
        // Default no-op. Factories can override to release per-view resources.
    }

    func insertChild(_ child: NSView, into parent: NSView, before anchor: NSView?) {
        if let anchor = anchor, parent.subviews.contains(anchor) {
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

// MARK: - VueNativeComponentSupport

/// Core services a ``NativeComponentFactory`` needs but cannot reach across a
/// module boundary: the built-in style router and the shared hex color parser.
///
/// This is what lets a factory live outside `VueNativeMacOS` — the optional
/// `VueNativeMacOSSVG` product, or a host's own custom component — without
/// losing framework behaviour. Both are `internal` in core, so without this
/// wrapper an out-of-module factory would silently stop applying `width`,
/// `backgroundColor`, `borderRadius` and every other prop it does not handle
/// itself.
///
/// ```swift
/// func updateProp(view: NSView, key: String, value: Any?) {
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
    public static func applyStyle(key: String, value: Any?, to view: NSView) {
        StyleEngine.apply(key: key, value: value, to: view)
    }

    /// Parse a hex color string (`#rgb`, `#rrggbb`, `#rrggbbaa`, with or without
    /// the leading `#`) exactly as the built-in factories do. Returns `nil` for
    /// anything unparseable rather than falling back to a default color.
    public static func color(fromHex hex: String) -> NSColor? {
        NSColor.fromHex(hex)
    }
}
