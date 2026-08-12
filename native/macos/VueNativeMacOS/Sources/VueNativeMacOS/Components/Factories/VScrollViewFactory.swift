import AppKit
import ObjectiveC

/// Factory for VScrollView — scrollable container component.
/// Maps to NSScrollView with a FlippedView document view.
/// NSScrollView hierarchy: NSScrollView → NSClipView → documentView (FlippedView).
/// Children are added to the document view, not the scroll view itself.
final class VScrollViewFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var scrollThrottleKey: UInt8 = 0
    private static var scrollObserverKey: UInt8 = 0
    private static var scrollHandlerKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let scrollView = NSScrollView()
        scrollView.wantsLayer = true
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        // Create document view (children go here)
        let documentView = FlippedView()
        documentView.ensureLayoutNode()
        scrollView.documentView = documentView

        // Enable bounds change notifications on the clip view for scroll events
        scrollView.contentView.postsBoundsChangedNotifications = true

        scrollView.ensureLayoutNode()
        return scrollView
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let scrollView = view as? NSScrollView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "horizontal":
            let horizontal = (value as? Bool) ?? false
            scrollView.hasHorizontalScroller = horizontal
            scrollView.hasVerticalScroller = !horizontal

        case "showsVerticalScrollIndicator":
            let show = (value as? Bool) ?? true
            if show {
                scrollView.hasVerticalScroller = true
            } else {
                scrollView.hasVerticalScroller = false
            }

        case "showsHorizontalScrollIndicator":
            let show = (value as? Bool) ?? false
            if show {
                scrollView.hasHorizontalScroller = true
            } else {
                scrollView.hasHorizontalScroller = false
            }

        case "bounces":
            let bounces = (value as? Bool) ?? true
            scrollView.verticalScrollElasticity = bounces ? .allowed : .none
            scrollView.horizontalScrollElasticity = bounces ? .allowed : .none

        case "scrollEnabled":
            let enabled = (value as? Bool) ?? true
            // Disabling scroll by removing scrollers and preventing scroll
            if enabled {
                scrollView.hasVerticalScroller = true
                scrollView.verticalScrollElasticity = .allowed
            } else {
                scrollView.hasVerticalScroller = false
                scrollView.hasHorizontalScroller = false
                scrollView.verticalScrollElasticity = .none
                scrollView.horizontalScrollElasticity = .none
            }

        case "contentContainerStyle":
            // Apply styles to the document view
            if let styles = value as? [String: Any], let docView = scrollView.documentView {
                StyleEngine.applyStyles(styles, to: docView)
            }

        case "pagingEnabled":
            // NSScrollView doesn't have native paging. Store as internal prop.
            StyleEngine.setInternalPropDirect("__pagingEnabled", value: value, on: view)

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard let scrollView = view as? NSScrollView else { return }

        switch event {
        case "scroll":
            let throttle = EventThrottle(interval: 0.016) { payload in
                handler(payload)
            }
            objc_setAssociatedObject(
                view, &VScrollViewFactory.scrollThrottleKey,
                throttle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

            let observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak scrollView] _ in
                guard let sv = scrollView else { return }
                let clipBounds = sv.contentView.bounds
                let docSize = sv.documentView?.frame.size ?? .zero
                let visibleSize = sv.contentView.bounds.size

                let payload: [String: Any] = [
                    "x": clipBounds.origin.x,
                    "y": clipBounds.origin.y,
                    "contentWidth": docSize.width,
                    "contentHeight": docSize.height,
                    "layoutWidth": visibleSize.width,
                    "layoutHeight": visibleSize.height,
                ]
                throttle.fire(payload)
            }

            objc_setAssociatedObject(
                view, &VScrollViewFactory.scrollObserverKey,
                observer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        switch event {
        case "scroll":
            if let observer = objc_getAssociatedObject(view, &VScrollViewFactory.scrollObserverKey) {
                NotificationCenter.default.removeObserver(observer)
                objc_setAssociatedObject(
                    view, &VScrollViewFactory.scrollObserverKey,
                    nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
            objc_setAssociatedObject(
                view, &VScrollViewFactory.scrollThrottleKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    // MARK: - Child management (redirect to document view)

    func insertChild(_ child: NSView, into parent: NSView, before anchor: NSView?) {
        guard let scrollView = parent as? NSScrollView,
              let documentView = scrollView.documentView else {
            // Fallback: add directly
            if let anchor = anchor, parent.subviews.contains(anchor) {
                parent.addSubview(child, positioned: .below, relativeTo: anchor)
            } else {
                parent.addSubview(child)
            }
            child.ensureLayoutNode()
            return
        }

        if let anchor = anchor, documentView.subviews.contains(anchor) {
            documentView.addSubview(child, positioned: .below, relativeTo: anchor)
        } else {
            documentView.addSubview(child)
        }
        child.ensureLayoutNode()
    }

    func removeChild(_ child: NSView, from parent: NSView) {
        // Child is in the document view, just remove from superview
        child.removeFromSuperview()
    }

    // MARK: - Post-layout content sizing

    /// Recompute `documentView`'s children and resize it to fit them.
    /// `NativeBridge.triggerLayout()` calls this for every registered scroll
    /// view after the main `LayoutNode` pass, because that pass never
    /// reaches `documentView` on its own: it sits behind `NSClipView`
    /// (`NSScrollView` -> `NSClipView` -> `documentView`), and `LayoutNode
    /// .children` walks `view.subviews` directly, which stops at the
    /// (LayoutNode-less) clip view.
    ///
    /// `LayoutNode` (unlike iOS's real Yoga) has no "measure my natural size
    /// from content" mode -- a node's own resolved size is always derived
    /// top-down from the size its parent hands it, never bottom-up from its
    /// children. To approximate content-driven sizing without that
    /// capability, `documentView` is laid out against a generous sentinel
    /// size on the scroll axis (so children are never clipped mid-measure),
    /// then resized to the *actual* extent its children ended up at (the max
    /// `computedFrame` maxY/maxX among them) rather than the sentinel.
    ///
    /// Caveat: a child with `flexGrow > 0` has no real "available space" to
    /// grow into inside scrollable content, so it will expand toward the
    /// sentinel instead of its intended size -- the same ambiguity Yoga
    /// resolves with a dedicated measure pass that this simplified engine
    /// does not implement. Fixed/percentage/auto-sized children (the common
    /// case for scrollable content) size and position correctly; a
    /// `flexGrow` child directly inside a `VScrollView` does not.
    @MainActor
    static func layoutDocumentView(for scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView,
              let layoutNode = documentView.layoutNode else {
            // Not a plain VScrollView document view -- VList/VSectionList's
            // NSTableView and VOutlineView's NSOutlineView never get a
            // LayoutNode (they manage their own sizing) and must be left alone.
            return
        }

        let viewportSize = scrollView.contentView.bounds.size
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }

        // Mutually exclusive per `updateProp`'s "horizontal" case.
        let isHorizontal = scrollView.hasHorizontalScroller && !scrollView.hasVerticalScroller
        let sentinel: CGFloat = 100_000

        let passWidth = isHorizontal ? sentinel : viewportSize.width
        let passHeight = isHorizontal ? viewportSize.height : sentinel

        documentView.frame = CGRect(x: 0, y: 0, width: passWidth, height: passHeight)
        layoutNode.layout(availableWidth: passWidth, availableHeight: passHeight)

        let contentExtent = layoutNode.children.reduce(CGFloat(0)) { furthest, child in
            Swift.max(furthest, isHorizontal ? child.computedFrame.maxX : child.computedFrame.maxY)
        }

        let finalWidth = isHorizontal ? Swift.max(contentExtent, viewportSize.width) : viewportSize.width
        let finalHeight = isHorizontal ? viewportSize.height : Swift.max(contentExtent, viewportSize.height)
        documentView.frame = CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight)
    }
}
