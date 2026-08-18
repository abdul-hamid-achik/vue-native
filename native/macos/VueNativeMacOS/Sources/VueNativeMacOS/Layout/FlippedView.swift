import AppKit
import ObjectiveC

/// Base NSView subclass with flipped coordinate system (origin at top-left).
/// All Vue Native views should inherit from this to match CSS/Yoga layout coordinates.
/// NSView's default coordinate system has origin at bottom-left, which conflicts with
/// web/CSS layout conventions where origin is top-left.
open class FlippedView: NSView {
    override open var isFlipped: Bool { true }

    private static var pointerEventsNoneKey: UInt8 = 0

    var ignoresPointerEvents: Bool {
        get { objc_getAssociatedObject(self, &Self.pointerEventsNoneKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &Self.pointerEventsNoneKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    override public init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true  // Enable layer-backed drawing for all views
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override open func hitTest(_ point: NSPoint) -> NSView? {
        if ignoresPointerEvents {
            return nil
        }
        return super.hitTest(point)
    }

    /// After every layout pass, report variable-height flat-list items.
    ///
    /// This is the canonical "layout finished" hook in AppKit. The call is a no-op for
    /// any view that is not a VFlatList item (no `__flatListIndex` + `itemLayout`
    /// handler), so the overhead for the common case is a single associated-object
    /// lookup. See `reportFlatListItemLayoutIfNeeded()`.
    override open func layout() {
        super.layout()
        reportFlatListItemLayoutIfNeeded()
    }
}
