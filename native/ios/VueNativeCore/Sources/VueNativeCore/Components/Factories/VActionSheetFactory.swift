#if canImport(UIKit)
import UIKit
import ObjectiveC

/// Factory for VActionSheet — presents a UIAlertController in .actionSheet style.
@MainActor
final class VActionSheetFactory: NativeComponentFactory {

    private let presentationHandler: (UIAlertController) -> Bool
    private let dismissalHandler: (UIAlertController) -> Void

    init(
        presentationHandler: ((UIAlertController) -> Bool)? = nil,
        dismissalHandler: ((UIAlertController) -> Void)? = nil
    ) {
        self.presentationHandler = presentationHandler ?? VActionSheetFactory.presentUsingApplication
        self.dismissalHandler = dismissalHandler ?? { $0.dismiss(animated: true) }
    }

    private static var titleKey: UInt8 = 0
    private static var messageKey: UInt8 = 1
    private static var actionsKey: UInt8 = 2
    private static var onActionKey: UInt8 = 3
    private static var onCancelKey: UInt8 = 4
    private static var presentedKey: UInt8 = 5

    func createView() -> UIView {
        let v = UIView(); v.isHidden = true; return v
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        switch key {
        case "visible":
            let visible = (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? false
            if visible {
                presentSheet(for: view)
            } else {
                dismissSheet(for: view)
            }
        case "title":
            objc_setAssociatedObject(view, &VActionSheetFactory.titleKey, value as? String, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "message":
            objc_setAssociatedObject(view, &VActionSheetFactory.messageKey, value as? String, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "actions":
            objc_setAssociatedObject(view, &VActionSheetFactory.actionsKey, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default: break
        }
    }

    private func presentSheet(for view: UIView) {
        guard objc_getAssociatedObject(view, &VActionSheetFactory.presentedKey) == nil else { return }

        let title   = objc_getAssociatedObject(view, &VActionSheetFactory.titleKey) as? String
        let message = objc_getAssociatedObject(view, &VActionSheetFactory.messageKey) as? String
        let actions = objc_getAssociatedObject(view, &VActionSheetFactory.actionsKey) as? [[String: Any]] ?? []

        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)

        for action in actions {
            let label    = action["label"] as? String ?? "Action"
            let styleStr = action["style"] as? String ?? "default"
            let style: UIAlertAction.Style = styleStr == "destructive" ? .destructive : (styleStr == "cancel" ? .cancel : .default)
            alert.addAction(UIAlertAction(title: label, style: style) { [weak view] _ in
                guard let view = view else { return }
                objc_setAssociatedObject(
                    view, &VActionSheetFactory.presentedKey,
                    nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                if styleStr == "cancel" {
                    (objc_getAssociatedObject(view, &VActionSheetFactory.onCancelKey) as? ((Any?) -> Void))?(nil)
                } else {
                    (objc_getAssociatedObject(view, &VActionSheetFactory.onActionKey) as? ((Any?) -> Void))?(["label": label])
                }
            })
        }

        if !actions.contains(where: { ($0["style"] as? String) == "cancel" }) {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak view] _ in
                guard let view = view else { return }
                objc_setAssociatedObject(
                    view, &VActionSheetFactory.presentedKey,
                    nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                (objc_getAssociatedObject(view, &VActionSheetFactory.onCancelKey) as? ((Any?) -> Void))?(nil)
            })
        }

        guard presentationHandler(alert) else { return }
        objc_setAssociatedObject(
            view, &VActionSheetFactory.presentedKey,
            alert, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private func dismissSheet(for view: UIView) {
        guard let alert = objc_getAssociatedObject(
            view, &VActionSheetFactory.presentedKey
        ) as? UIAlertController else { return }
        objc_setAssociatedObject(
            view, &VActionSheetFactory.presentedKey,
            nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        dismissalHandler(alert)
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        switch event {
        case "action": objc_setAssociatedObject(view, &VActionSheetFactory.onActionKey, handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "cancel": objc_setAssociatedObject(view, &VActionSheetFactory.onCancelKey, handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default: break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        switch event {
        case "action": objc_setAssociatedObject(view, &VActionSheetFactory.onActionKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "cancel": objc_setAssociatedObject(view, &VActionSheetFactory.onCancelKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default: break
        }
    }

    func destroyView(view: UIView) {
        objc_setAssociatedObject(view, &VActionSheetFactory.onActionKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VActionSheetFactory.onCancelKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        dismissSheet(for: view)
    }

    private static func presentUsingApplication(_ alert: UIAlertController) -> Bool {
        guard let rootViewController = UIApplication.shared.vn_keyWindow?.rootViewController else {
            return false
        }
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        if let popover = alert.popoverPresentationController {
            popover.sourceView = topViewController.view
            popover.sourceRect = CGRect(
                x: topViewController.view.bounds.midX,
                y: topViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        topViewController.present(alert, animated: true)
        return true
    }
}
#endif
