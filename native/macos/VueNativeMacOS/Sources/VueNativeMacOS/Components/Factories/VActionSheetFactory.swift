import AppKit
import ObjectiveC

/// Factory for VActionSheet — maps to NSMenu (context menu) on macOS.
/// macOS has no action sheet UI; an NSMenu popup is the closest equivalent.
/// The view itself is a zero-size hidden placeholder in the native tree.
final class VActionSheetFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var actionsKey: UInt8 = 0
    private static var cancelLabelKey: UInt8 = 1
    nonisolated(unsafe) static var onActionKey: UInt8 = 2
    nonisolated(unsafe) static var onCancelKey: UInt8 = 3
    private static var menuDelegateKey: UInt8 = 4

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
                showMenu(for: view)
            }

        case "title":
            // Ignored on macOS — NSMenu doesn't display a title in popup mode
            break

        case "actions":
            objc_setAssociatedObject(
                view, &VActionSheetFactory.actionsKey,
                value,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "cancelLabel":
            objc_setAssociatedObject(
                view, &VActionSheetFactory.cancelLabelKey,
                value as? String,
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
                view, &VActionSheetFactory.onActionKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        case "cancel":
            objc_setAssociatedObject(
                view, &VActionSheetFactory.onCancelKey,
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
            objc_setAssociatedObject(view, &VActionSheetFactory.onActionKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "cancel":
            objc_setAssociatedObject(view, &VActionSheetFactory.onCancelKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default:
            break
        }
    }

    // MARK: - Menu presentation

    private func showMenu(for view: NSView) {
        let menu = NSMenu()

        // Parse actions — supports [String] and [[String: Any]] with {label, destructive?}
        var actionLabels: [String] = []
        if let actions = objc_getAssociatedObject(view, &VActionSheetFactory.actionsKey) as? [String] {
            actionLabels = actions
        } else if let actions = objc_getAssociatedObject(view, &VActionSheetFactory.actionsKey) as? [[String: Any]] {
            actionLabels = actions.compactMap { $0["label"] as? String }
        }

        // Create proxy to handle menu item selection
        let proxy = ActionSheetProxy(view: view)
        objc_setAssociatedObject(
            view, &VActionSheetFactory.menuDelegateKey,
            proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        for (index, label) in actionLabels.enumerated() {
            let item = NSMenuItem(title: label, action: #selector(ActionSheetProxy.itemSelected(_:)), keyEquivalent: "")
            item.target = proxy
            item.tag = index
            menu.addItem(item)
        }

        // Add separator + cancel item if cancelLabel is set
        if let cancelLabel = objc_getAssociatedObject(view, &VActionSheetFactory.cancelLabelKey) as? String {
            menu.addItem(.separator())
            let cancelItem = NSMenuItem(title: cancelLabel, action: #selector(ActionSheetProxy.cancelSelected(_:)), keyEquivalent: "")
            cancelItem.target = proxy
            cancelItem.tag = -1
            menu.addItem(cancelItem)
        }

        // Pop up the menu at the view's location (use superview if placeholder is hidden)
        let targetView = view.superview ?? view
        let location = NSPoint(x: 0, y: 0)
        menu.popUp(positioning: nil, at: location, in: targetView)
    }
}

// MARK: - ActionSheetProxy

/// Target-action proxy for NSMenu item selection.
private final class ActionSheetProxy: NSObject {
    private weak var view: NSView?

    init(view: NSView) {
        self.view = view
    }

    @objc func itemSelected(_ sender: NSMenuItem) {
        guard let view = view else { return }
        if let handler = objc_getAssociatedObject(view, &VActionSheetFactory.onActionKey) as? ((Any?) -> Void) {
            handler(["label": sender.title, "index": sender.tag])
        }
    }

    @objc func cancelSelected(_ sender: NSMenuItem) {
        guard let view = view else { return }
        if let handler = objc_getAssociatedObject(view, &VActionSheetFactory.onCancelKey) as? ((Any?) -> Void) {
            handler(nil)
        }
    }
}
