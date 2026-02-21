#if canImport(UIKit)
import UIKit
import ObjectiveC

/// Factory for VAlertDialog — presents a UIAlertController when `visible=true`.
/// The view itself is a zero-size, hidden placeholder in the native tree.
@MainActor
final class VAlertDialogFactory: NativeComponentFactory {

    // MARK: - Associated-object keys (each must be a unique address)

    private static var titleKey: UInt8 = 0
    private static var messageKey: UInt8 = 1
    private static var buttonsKey: UInt8 = 2
    private static var onConfirmKey: UInt8 = 3
    private static var onCancelKey: UInt8 = 4
    private static var onActionKey: UInt8 = 5
    private static var presentedKey: UInt8 = 6

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let v = UIView()
        v.isHidden = true
        return v
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        switch key {
        case "visible":
            let visible = (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? false
            if visible {
                presentAlert(for: view)
            }
        case "title":
            objc_setAssociatedObject(
                view, &VAlertDialogFactory.titleKey,
                value as? String,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        case "message":
            objc_setAssociatedObject(
                view, &VAlertDialogFactory.messageKey,
                value as? String,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        case "buttons":
            objc_setAssociatedObject(
                view, &VAlertDialogFactory.buttonsKey,
                value,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        default:
            break
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        switch event {
        case "confirm":
            objc_setAssociatedObject(
                view, &VAlertDialogFactory.onConfirmKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        case "cancel":
            objc_setAssociatedObject(
                view, &VAlertDialogFactory.onCancelKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        case "action":
            objc_setAssociatedObject(
                view, &VAlertDialogFactory.onActionKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        switch event {
        case "confirm":
            objc_setAssociatedObject(view, &VAlertDialogFactory.onConfirmKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "cancel":
            objc_setAssociatedObject(view, &VAlertDialogFactory.onCancelKey,  nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "action":
            objc_setAssociatedObject(view, &VAlertDialogFactory.onActionKey,  nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default:
            break
        }
    }

    // MARK: - Alert Presentation

    private func presentAlert(for view: UIView) {
        let title   = objc_getAssociatedObject(view, &VAlertDialogFactory.titleKey)   as? String
        let message = objc_getAssociatedObject(view, &VAlertDialogFactory.messageKey) as? String
        let buttons = objc_getAssociatedObject(view, &VAlertDialogFactory.buttonsKey) as? [[String: Any]] ?? []

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        for button in buttons {
            let label    = button["label"]  as? String ?? "OK"
            let styleStr = button["style"]  as? String ?? "default"
            let style: UIAlertAction.Style
            switch styleStr {
            case "destructive": style = .destructive
            case "cancel":      style = .cancel
            default:            style = .default
            }

            alert.addAction(UIAlertAction(title: label, style: style) { [weak view] _ in
                guard let view = view else { return }
                if styleStr == "cancel" {
                    if let h = objc_getAssociatedObject(view, &VAlertDialogFactory.onCancelKey) as? ((Any?) -> Void) {
                        h(nil)
                    }
                } else {
                    if let h = objc_getAssociatedObject(view, &VAlertDialogFactory.onActionKey) as? ((Any?) -> Void) {
                        h(["label": label])
                    }
                    if let h = objc_getAssociatedObject(view, &VAlertDialogFactory.onConfirmKey) as? ((Any?) -> Void) {
                        h(["label": label])
                    }
                }
            })
        }

        // Fallback: single OK button when no buttons are configured
        if alert.actions.isEmpty {
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak view] _ in
                guard let view = view else { return }
                if let h = objc_getAssociatedObject(view, &VAlertDialogFactory.onConfirmKey) as? ((Any?) -> Void) {
                    h(nil)
                }
            })
        }

        // Find the topmost presented view controller to present from
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }
        topVC.present(alert, animated: true)
    }
}
#endif
