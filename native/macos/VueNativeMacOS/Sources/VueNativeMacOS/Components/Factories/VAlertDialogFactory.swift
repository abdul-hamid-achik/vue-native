import AppKit
import ObjectiveC

/// Factory for VAlertDialog — presents an NSAlert when `visible=true`.
/// The view itself is a zero-size, hidden placeholder in the native tree.
final class VAlertDialogFactory: NativeComponentFactory {

    // MARK: - Associated-object keys

    private static var titleKey: UInt8 = 0
    private static var messageKey: UInt8 = 1
    private static var buttonsKey: UInt8 = 2
    private static var onActionKey: UInt8 = 3

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let view = FlippedView()
        view.isHidden = true
        let node = view.ensureLayoutNode()
        node.width = .points(0)
        node.height = .points(0)
        return view
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        switch key {
        case "visible":
            let visible = (value as? Bool) ?? ((value as? Int).map { $0 != 0 } ?? false)
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

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        switch event {
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

    func removeEventListener(view: NSView, event: String) {
        switch event {
        case "action":
            objc_setAssociatedObject(view, &VAlertDialogFactory.onActionKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default:
            break
        }
    }

    // MARK: - Alert Presentation

    private func presentAlert(for view: NSView) {
        let title = objc_getAssociatedObject(view, &VAlertDialogFactory.titleKey) as? String
        let message = objc_getAssociatedObject(view, &VAlertDialogFactory.messageKey) as? String

        let alert = NSAlert()
        alert.messageText = title ?? ""
        alert.informativeText = message ?? ""
        alert.alertStyle = .informational

        // Parse buttons — supports both [String] and [[String: Any]] formats
        var buttonLabels: [String] = []
        if let buttonsArray = objc_getAssociatedObject(view, &VAlertDialogFactory.buttonsKey) as? [String] {
            buttonLabels = buttonsArray
        } else if let buttonsArray = objc_getAssociatedObject(view, &VAlertDialogFactory.buttonsKey) as? [[String: Any]] {
            buttonLabels = buttonsArray.compactMap { $0["label"] as? String }
        }

        // Add buttons (first is default, last is cancel style if > 1)
        if buttonLabels.isEmpty {
            alert.addButton(withTitle: "OK")
            buttonLabels = ["OK"]
        } else {
            for label in buttonLabels {
                alert.addButton(withTitle: label)
            }
        }

        // Present as sheet if we have a key window, otherwise run modal
        if let window = NSApplication.shared.keyWindow {
            alert.beginSheetModal(for: window) { [weak view] response in
                guard let view = view else { return }
                let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
                let label = index < buttonLabels.count ? buttonLabels[index] : ""
                self.fireAction(for: view, buttonIndex: index, buttonLabel: label)
            }
        } else {
            let response = alert.runModal()
            let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            let label = index < buttonLabels.count ? buttonLabels[index] : ""
            fireAction(for: view, buttonIndex: index, buttonLabel: label)
        }
    }

    private func fireAction(for view: NSView, buttonIndex: Int, buttonLabel: String) {
        if let handler = objc_getAssociatedObject(view, &VAlertDialogFactory.onActionKey) as? ((Any?) -> Void) {
            handler(["buttonIndex": buttonIndex, "buttonLabel": buttonLabel])
        }
    }
}
