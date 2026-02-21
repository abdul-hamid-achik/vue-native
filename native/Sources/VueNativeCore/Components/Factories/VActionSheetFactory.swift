#if canImport(UIKit)
import UIKit
import ObjectiveC

/// Factory for VActionSheet — presents a UIAlertController in .actionSheet style.
final class VActionSheetFactory: NativeComponentFactory {

    private static var titleKey: UInt8 = 0
    private static var messageKey: UInt8 = 1
    private static var actionsKey: UInt8 = 2
    private static var onActionKey: UInt8 = 3
    private static var onCancelKey: UInt8 = 4

    func createView() -> UIView {
        let v = UIView(); v.isHidden = true; return v
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        switch key {
        case "visible":
            let visible = (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? false
            if visible { presentSheet(for: view) }
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
                (objc_getAssociatedObject(view, &VActionSheetFactory.onCancelKey) as? ((Any?) -> Void))?(nil)
            })
        }

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return }
        var top = rootVC
        while let p = top.presentedViewController { top = p }

        // iPad popover
        if let pop = alert.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(alert, animated: true)
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
}
#endif
