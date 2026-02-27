#if canImport(UIKit)
import UIKit
import ObjectiveC
import FlexLayout

/// Factory for VScrollView — the scrollable container component.
///
/// Maps to UIScrollView on iOS. An inner `contentView` UIView is created as
/// a subview and managed separately from the scroll view's Yoga node. All
/// children reported by the bridge are inserted into the contentView, not
/// the scroll view itself.
///
/// After each main layout pass, NativeBridge calls `layoutContentView(for:)`
/// to compute the contentView's natural height (unconstrained) and update
/// the scroll view's contentSize.
final class VScrollViewFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    static var contentViewKey: UInt8 = 0
    static var delegateProxyKey: UInt8 = 1
    static var onRefreshKey: UInt8 = 5
    static var refreshTargetKey: UInt8 = 6

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.clipsToBounds = true
        _ = scrollView.flex

        // Content view: children are added here so Yoga can measure
        // their natural size without being constrained by the scroll view's bounds.
        let contentView = UIView()
        _ = contentView.flex
        scrollView.addSubview(contentView)

        objc_setAssociatedObject(
            scrollView,
            &VScrollViewFactory.contentViewKey,
            contentView,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        return scrollView
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let scrollView = view as? UIScrollView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "horizontal":
            let horizontal: Bool
            if let h = value as? Bool { horizontal = h }
            else if let h = value as? Int { horizontal = h != 0 }
            else { horizontal = false }
            scrollView.alwaysBounceHorizontal = horizontal
            scrollView.alwaysBounceVertical = !horizontal

        case "showsVerticalScrollIndicator":
            if let shows = value as? Bool { scrollView.showsVerticalScrollIndicator = shows }

        case "showsHorizontalScrollIndicator":
            if let shows = value as? Bool { scrollView.showsHorizontalScrollIndicator = shows }

        case "scrollEnabled":
            if let enabled = value as? Bool { scrollView.isScrollEnabled = enabled }
            else if let enabled = value as? Int { scrollView.isScrollEnabled = enabled != 0 }

        case "bounces":
            if let bounces = value as? Bool { scrollView.bounces = bounces }

        case "pagingEnabled":
            if let paging = value as? Bool { scrollView.isPagingEnabled = paging }

        case "refreshing":
            let refreshing: Bool
            if let b = value as? Bool { refreshing = b }
            else if let n = value as? NSNumber { refreshing = n.boolValue }
            else { refreshing = false }

            if refreshing {
                // Add UIRefreshControl if not already present
                if scrollView.refreshControl == nil {
                    let control = UIRefreshControl()
                    scrollView.refreshControl = control
                }
                scrollView.refreshControl?.beginRefreshing()
            } else {
                scrollView.refreshControl?.endRefreshing()
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard let scrollView = view as? UIScrollView else { return }
        switch event {
        case "scroll":
            let proxy = ScrollDelegateProxy(handler: handler)
            objc_setAssociatedObject(
                scrollView,
                &VScrollViewFactory.delegateProxyKey,
                proxy,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            scrollView.delegate = proxy
        case "refresh":
            // Store the handler
            objc_setAssociatedObject(
                scrollView,
                &VScrollViewFactory.onRefreshKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            // Create UIRefreshControl if not already present
            if scrollView.refreshControl == nil {
                scrollView.refreshControl = UIRefreshControl()
            }
            guard let refreshControl = scrollView.refreshControl else { break }
            // Create a target helper and store it
            let target = RefreshTarget(handler: handler)
            objc_setAssociatedObject(
                scrollView,
                &VScrollViewFactory.refreshTargetKey,
                target,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            refreshControl.addTarget(target, action: #selector(RefreshTarget.handleRefresh), for: .valueChanged)

        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        guard let scrollView = view as? UIScrollView, event == "scroll" else { return }
        scrollView.delegate = nil
        objc_setAssociatedObject(
            scrollView,
            &VScrollViewFactory.delegateProxyKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    // MARK: - Child management

    func insertChild(_ child: UIView, into parent: UIView, before anchor: UIView?) {
        if let anchor = anchor, let idx = parent.subviews.firstIndex(of: anchor) {
            parent.insertSubview(child, at: idx)
        } else {
            parent.addSubview(child)
        }
        // Ensure content size is recalculated after child insertion
        if let scrollView = parent.superview as? UIScrollView {
            scrollView.setNeedsLayout()
        }
    }

    func removeChild(_ child: UIView, from parent: UIView) {
        child.removeFromSuperview()
        // Ensure content size is recalculated after child removal
        if let scrollView = parent.superview as? UIScrollView {
            scrollView.setNeedsLayout()
        }
    }

    // MARK: - Static helpers

    /// Retrieve the inner content UIView for a scroll view.
    /// NativeBridge calls this to redirect child insertions.
    static func contentView(for scrollView: UIScrollView) -> UIView? {
        return objc_getAssociatedObject(scrollView, &contentViewKey) as? UIView
    }

    /// Recompute the content view's layout and update the scroll view's contentSize.
    /// Call this after the main Yoga layout pass, once the scroll view's frame is set.
    @MainActor
    static func layoutContentView(for scrollView: UIScrollView) {
        guard let contentView = contentView(for: scrollView) else { return }

        let scrollWidth = scrollView.bounds.width
        guard scrollWidth > 0 else { return }

        // Pin the content view's origin and width
        contentView.frame = CGRect(x: 0, y: 0, width: scrollWidth, height: 0)

        // Compute natural height — adjustHeight mode grows height to fit children
        contentView.flex.layout(mode: .adjustHeight)

        // Update the scroll view's scrollable content size
        scrollView.contentSize = contentView.frame.size
    }
}

// MARK: - RefreshTarget

/// ObjC-compatible target for UIRefreshControl value-changed actions.
private final class RefreshTarget: NSObject {
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handleRefresh() {
        handler(nil)
    }
}

// MARK: - ScrollDelegateProxy

/// UIScrollViewDelegate proxy that forwards scroll events to a JS handler.
/// Uses EventThrottle to limit bridge round-trips to ~60/s during fast scrolling.
private final class ScrollDelegateProxy: NSObject, UIScrollViewDelegate {
    private let throttle: EventThrottle

    init(handler: @escaping (Any?) -> Void) {
        self.throttle = EventThrottle(interval: 0.016, handler: handler)
        super.init()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let payload: [String: Any] = [
            "x": scrollView.contentOffset.x,
            "y": scrollView.contentOffset.y,
            "contentWidth": scrollView.contentSize.width,
            "contentHeight": scrollView.contentSize.height,
            "layoutWidth": scrollView.frame.width,
            "layoutHeight": scrollView.frame.height,
        ]
        throttle.fire(payload)
    }
}
#endif
