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
            if let b = value as? Bool { refreshing = b }
            else if let n = value as? NSNumber { refreshing = n.boolValue }
            else if let n = value as? Int { refreshing = n != 0 }
            else { refreshing = false }

            if refreshing {
                refreshControl.beginRefreshing()
            } else {
                refreshControl.endRefreshing()
            }

        case "tintColor":
            if let hex = value as? String {
                refreshControl.tintColor = UIColor.fromHex(hex)
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

        // Create ObjC-compatible target
        let target = RefreshControlTarget(handler: handler)
        objc_setAssociatedObject(
            view,
            &VRefreshControlFactory.refreshTargetKey,
            target,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        refreshControl.addTarget(target, action: #selector(RefreshControlTarget.handleRefresh), for: .valueChanged)
    }

    func removeEventListener(view: UIView, event: String) {
        guard event == "refresh" else { return }
        guard let refreshControl = objc_getAssociatedObject(
            view,
            &VRefreshControlFactory.refreshControlKey
        ) as? UIRefreshControl else { return }

        refreshControl.removeTarget(nil, action: nil, for: .valueChanged)
        objc_setAssociatedObject(view, &VRefreshControlFactory.refreshTargetKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VRefreshControlFactory.refreshHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
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
    }

    // MARK: - Static helpers

    /// Retrieve the UIRefreshControl stored on a VRefreshControl wrapper view.
    static func refreshControl(for view: UIView) -> UIRefreshControl? {
        return objc_getAssociatedObject(view, &refreshControlKey) as? UIRefreshControl
    }
}

// MARK: - RefreshControlTarget

/// ObjC-compatible target for UIRefreshControl .valueChanged action.
private final class RefreshControlTarget: NSObject {
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handleRefresh() {
        handler(nil)
    }
}
#endif
