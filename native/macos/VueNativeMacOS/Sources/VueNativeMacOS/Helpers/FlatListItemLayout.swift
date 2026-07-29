import AppKit
import ObjectiveC

/// Storage + height reporting for VFlatList variable-height items.
///
/// The runtime renders each flat-list item as a `VView` carrying a `__flatListIndex`
/// prop (its index in the data set) and an `itemLayout` event listener. When an item
/// finishes layout, native measures its real height and emits `itemLayout` with
/// `{ "index": Int, "height": Double }` so the list can size rows for variable-height
/// content.
///
/// Backed by associated objects so it works for any `NSView` without subclassing,
/// mirroring `NativeDrivenGestureStorage`. The height is only re-emitted when it
/// actually changes (within a small tolerance) to avoid feedback loops with the list's
/// row-sizing logic.
enum FlatListItemStorage {
    private static var indexKey: UInt8 = 0
    private static var handlerKey: UInt8 = 0
    private static var lastHeightKey: UInt8 = 0

    // MARK: - __flatListIndex

    static func setIndex(_ index: Int?, for view: NSView) {
        let number = index.map { NSNumber(value: $0) }
        objc_setAssociatedObject(view, &indexKey, number, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func index(for view: NSView) -> Int? {
        (objc_getAssociatedObject(view, &indexKey) as? NSNumber)?.intValue
    }

    // MARK: - itemLayout handler

    static func setHandler(_ handler: ((Any?) -> Void)?, for view: NSView) {
        let box = handler.map(HandlerBox.init)
        objc_setAssociatedObject(view, &handlerKey, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func handler(for view: NSView) -> ((Any?) -> Void)? {
        (objc_getAssociatedObject(view, &handlerKey) as? HandlerBox)?.handler
    }

    // MARK: - Last reported height (loop guard)

    static func setLastHeight(_ height: CGFloat?, for view: NSView) {
        let number = height.map { NSNumber(value: Double($0)) }
        objc_setAssociatedObject(view, &lastHeightKey, number, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func lastHeight(for view: NSView) -> CGFloat? {
        guard let number = objc_getAssociatedObject(view, &lastHeightKey) as? NSNumber else { return nil }
        return CGFloat(number.doubleValue)
    }
}

/// NSObject box so a Swift closure can be retained as an associated object.
private final class HandlerBox: NSObject {
    let handler: (Any?) -> Void

    init(_ handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }
}

extension NSView {
    /// Measure this item's laid-out height and, if it changed since the last report,
    /// emit `itemLayout` with `{ "index": <__flatListIndex>, "height": <height> }`.
    ///
    /// No-op unless this view is a flat-list item — i.e. it has both a stored
    /// `__flatListIndex` and an `itemLayout` handler. Safe (and cheap) to call on every
    /// layout pass: it bails out after a single associated-object lookup when the view
    /// is not a flat-list item, and the height comparison guards against re-emitting an
    /// unchanged height (which would otherwise loop with the list's row sizing).
    ///
    /// Height source: the LayoutNode's `computedFrame.height` when available (the
    /// flexbox-computed height), falling back to `frame.height` (the AppKit-assigned
    /// frame, e.g. when the item is hosted inside a table cell).
    func reportFlatListItemLayoutIfNeeded() {
        guard let handler = FlatListItemStorage.handler(for: self),
              let index = FlatListItemStorage.index(for: self) else {
            return
        }

        let height: CGFloat
        if let computed = layoutNode?.computedFrame.height, computed > 0 {
            height = computed
        } else {
            height = frame.height
        }
        guard height > 0 else { return }

        // Only emit on a real change (sub-half-point tolerance to ignore jitter).
        if let last = FlatListItemStorage.lastHeight(for: self), abs(last - height) < 0.5 {
            return
        }
        FlatListItemStorage.setLastHeight(height, for: self)

        handler([
            "index": index,
            "height": Double(height)
        ] as [String: Any])
    }
}
