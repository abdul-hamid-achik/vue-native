import AppKit

/// Base NSView subclass with flipped coordinate system (origin at top-left).
/// All Vue Native views should inherit from this to match CSS/Yoga layout coordinates.
/// NSView's default coordinate system has origin at bottom-left, which conflicts with
/// web/CSS layout conventions where origin is top-left.
open class FlippedView: NSView {
    override open var isFlipped: Bool { true }

    override public init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true  // Enable layer-backed drawing for all views
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
}
