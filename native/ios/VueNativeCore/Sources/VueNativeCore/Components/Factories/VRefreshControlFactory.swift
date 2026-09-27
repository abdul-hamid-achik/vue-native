#if canImport(UIKit)
import UIKit
import ObjectiveC
import FlexLayout

/// Factory for VRefreshControl — the pull-to-refresh indicator component.
///
/// Creates a lightweight UIView wrapper. When this view is inserted as a child
/// of a UIScrollView (via VScrollView or VList), the factory attaches a
/// UIRefreshControl to the parent scroll view's `.refreshControl` property.
final class VRefreshControlFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var refreshControlKey: UInt8 = 0
    private static var refreshTargetKey: UInt8 = 1
    private static var refreshHandlerKey: UInt8 = 2

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        // The wrapper view is zero-sized and invisible.
        // The actual UIRefreshControl is attached to the parent scroll view.
        let wrapper = UIView()
        wrapper.isHidden = true
        wrapper.frame = .zero

        // Create the UIRefreshControl and store it on the wrapper
        let refreshControl = UIRefreshControl()
        objc_setAssociatedObject(
            wrapper,
            &VRefreshControlFactory.refreshControlKey,
            refreshControl,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        return wrapper
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let refreshControl = objc_getAssociatedObject(
            view,
            &VRefreshControlFactory.refreshControlKey
        ) as? UIRefreshControl else { return }

        switch key {
        case "refreshing":
            let refreshing: Bool
            if let boolValue = value as? Bool {
                refreshing = boolValue
            } else if let numberValue = value as? NSNumber {
                refreshing = numberValue.boolValue
            } else if let intValue = value as? Int {
                refreshing = intValue != 0
            } else {
                refreshing = false
            }

            if refreshing {
                refreshControl.beginRefreshing()
            } else {
                refreshControl.endRefreshing()
            }

        case "tintColor":
            if let hex = value as? String {
                if let color = UIColor.fromHex(hex) {
                    refreshControl.tintColor = color
                }
            } else {
                refreshControl.tintColor = nil
            }

        case "title":
            if let text = value as? String {
                refreshControl.attributedTitle = NSAttributedString(string: text)
            } else {
                refreshControl.attributedTitle = nil
            }

        default:
            break
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard event == "refresh" else { return }
        guard let refreshControl = objc_getAssociatedObject(
            view,
            &VRefreshControlFactory.refreshControlKey
        ) as? UIRefreshControl else { return }

        // Store handler reference
        objc_setAssociatedObject(
            view,
            &VRefreshControlFactory.refreshHandlerKey,
            handler as AnyObject,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        // UIControl does NOT retain its targets. Storing a freshly built target in
        // the associated object releases the previous one while the control still
        // holds an unretained pointer to it, so a second `addEventListener("refresh")`
        // (Vue rebinds whenever a handler closure's identity changes) leaves a
        // dangling target behind and the next pull crashes with EXC_BAD_ACCESS.
        // Keep ONE long-lived target per wrapper and only swap its closure.
        let target: RefreshControlTarget
        if let existing = objc_getAssociatedObject(
            view,
            &VRefreshControlFactory.refreshTargetKey
        ) as? RefreshControlTarget {
            target = existing
        } else {
            target = RefreshControlTarget()
            objc_setAssociatedObject(
                view,
                &VRefreshControlFactory.refreshTargetKey,
                target,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            refreshControl.addTarget(
                target,
                action: #selector(RefreshControlTarget.handleRefresh),
                for: .valueChanged
            )
        }
        target.handler = handler
    }

    func removeEventListener(view: UIView, event: String) {
        guard event == "refresh" else { return }
        guard let refreshControl = objc_getAssociatedObject(
            view,
            &VRefreshControlFactory.refreshControlKey
        ) as? UIRefreshControl else { return }

        // Drop our own target explicitly before clearing the association that keeps
        // it alive; `removeTarget(nil, ...)` would unregister targets this wrapper
        // does not own as well.
        if let target = objc_getAssociatedObject(
            view,
            &VRefreshControlFactory.refreshTargetKey
        ) as? RefreshControlTarget {
            target.handler = nil
            refreshControl.removeTarget(
                target,
                action: #selector(RefreshControlTarget.handleRefresh),
                for: .valueChanged
            )
        }
        objc_setAssociatedObject(view, &VRefreshControlFactory.refreshTargetKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VRefreshControlFactory.refreshHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// The wrapper is permanently leaving the tree: make sure it does not leave its
    /// `UIRefreshControl` installed on an ancestor scroll view, and that the target
    /// is unregistered before the association retaining it is torn down.
    func destroyView(view: UIView) {
        var ancestor: UIView? = view.superview
        while let current = ancestor {
            if let scrollView = current as? UIScrollView,
               let control = VRefreshControlFactory.refreshControl(for: view),
               scrollView.refreshControl === control {
                scrollView.refreshControl = nil
                break
            }
            ancestor = current.superview
        }
        removeEventListener(view: view, event: "refresh")
    }

    // MARK: - Child management

    /// When inserted into a parent, attach the UIRefreshControl to the
    /// nearest UIScrollView ancestor.
    func insertChild(_ child: UIView, into parent: UIView, before anchor: UIView?) {
        // Default: just add as subview (hidden, zero-frame)
        if let anchor = anchor, let idx = parent.subviews.firstIndex(of: anchor) {
            parent.insertSubview(child, at: idx)
        } else {
            parent.addSubview(child)
        }
        // Defensive path. The bridge normally routes a `<VRefreshControl>` insertion
        // through the *parent's* factory (see `VScrollViewFactory.insertChild`), so
        // this only runs when the wrapper is itself the parent. Re-assert the
        // wrapper's own control — a custom host factory for the scroll view could
        // have bypassed the normal path — and attach any wrapper arriving as a child,
        // so neither case is silently inert.
        VRefreshControlFactory.attach(wrapper: parent, from: parent)
        VRefreshControlFactory.attach(wrapper: child, from: parent)
    }

    // MARK: - Static helpers

    /// Retrieve the UIRefreshControl stored on a VRefreshControl wrapper view.
    static func refreshControl(for view: UIView) -> UIRefreshControl? {
        return objc_getAssociatedObject(view, &refreshControlKey) as? UIRefreshControl
    }

    /// Install `wrapper`'s `UIRefreshControl` on the nearest `UIScrollView` at or
    /// above `container`. A no-op when `wrapper` is not a VRefreshControl view or
    /// when no scroll view encloses it.
    @MainActor
    static func attach(wrapper: UIView, from container: UIView) {
        guard let control = refreshControl(for: wrapper) else { return }
        guard let scrollView = nearestScrollView(from: container) else { return }
        guard scrollView.refreshControl !== control else { return }
        scrollView.refreshControl = control
    }

    /// Remove `wrapper`'s `UIRefreshControl` from the enclosing scroll view, but
    /// only when that scroll view is still showing this wrapper's control.
    @MainActor
    static func detach(wrapper: UIView, from container: UIView) {
        guard let control = refreshControl(for: wrapper) else { return }
        guard let scrollView = nearestScrollView(from: container) else { return }
        guard scrollView.refreshControl === control else { return }
        scrollView.refreshControl = nil
    }

    /// Walk up from `view` (inclusive) to the first `UIScrollView`.
    @MainActor
    private static func nearestScrollView(from view: UIView) -> UIScrollView? {
        var candidate: UIView? = view
        while let current = candidate {
            if let scrollView = current as? UIScrollView { return scrollView }
            candidate = current.superview
        }
        return nil
    }
}

// MARK: - RefreshControlTarget

/// ObjC-compatible target for UIRefreshControl .valueChanged action.
///
/// `handler` is mutable because `UIControl` holds its targets unretained: the
/// instance must outlive every rebind, so only the closure is swapped.
private final class RefreshControlTarget: NSObject {
    var handler: ((Any?) -> Void)?

    @objc func handleRefresh() {
        handler?(nil)
    }
}
#endif
