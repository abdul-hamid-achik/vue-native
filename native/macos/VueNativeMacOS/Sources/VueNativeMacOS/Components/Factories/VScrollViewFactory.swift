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
                    "contentOffset": [
                        "x": clipBounds.origin.x,
                        "y": clipBounds.origin.y
                    ],
                    "contentSize": [
                        "width": docSize.width,
                        "height": docSize.height
                    ],
                    "layoutMeasurement": [
                        "width": visibleSize.width,
                        "height": visibleSize.height
                    ]
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
            if let anchor = anchor, let idx = parent.subviews.firstIndex(of: anchor) {
                parent.addSubview(child, positioned: .below, relativeTo: anchor)
            } else {
                parent.addSubview(child)
            }
            child.ensureLayoutNode()
            return
        }

        if let anchor = anchor, let idx = documentView.subviews.firstIndex(of: anchor) {
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
}
