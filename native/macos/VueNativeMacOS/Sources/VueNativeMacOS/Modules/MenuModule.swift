import AppKit
import VueNativeShared

/// macOS-only module for menu bar control.
///
/// Methods:
///   - setAppMenu(items: [{ title, items: [{ title, key?, id?, separator?, disabled? }] }])
///   - showContextMenu(items: [{ title, key?, id?, separator?, disabled? }])
///
/// Events dispatched:
///   - menu:itemClick { id, title }
final class MenuModule: NativeModule {
    let moduleName = "Menu"
    private weak var dispatcher: NativeEventDispatcher?

    init(dispatcher: NativeEventDispatcher) {
        self.dispatcher = dispatcher
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            switch method {
            case "setAppMenu":
                guard let items = args.first as? [[String: Any]] else {
                    callback(nil, "Invalid args")
                    return
                }
                self?.buildMenu(items: items)
                callback(nil, nil)

            case "showContextMenu":
                guard let items = args.first as? [[String: Any]] else {
                    callback(nil, "Invalid args")
                    return
                }
                let menu = NSMenu()
                self?.addMenuItems(items, to: menu)

                if let window = NSApp.mainWindow, let view = window.contentView {
                    let location = NSEvent.mouseLocation
                    let windowPoint = window.convertPoint(fromScreen: location)
                    let viewPoint = view.convert(windowPoint, from: nil)
                    menu.popUp(positioning: nil, at: viewPoint, in: view)
                }
                callback(nil, nil)

            default:
                callback(nil, "MenuModule: Unknown method '\(method)'")
            }
        }
    }

    private func buildMenu(items: [[String: Any]]) {
        let mainMenu = NSMenu()
        for item in items {
            guard let title = item["title"] as? String else { continue }
            let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: title)
            if let children = item["items"] as? [[String: Any]] {
                addMenuItems(children, to: submenu)
            }
            menuItem.submenu = submenu
            mainMenu.addItem(menuItem)
        }
        NSApp.mainMenu = mainMenu
    }

    private func addMenuItems(_ items: [[String: Any]], to menu: NSMenu) {
        for item in items {
            if let separator = item["separator"] as? Bool, separator {
                menu.addItem(.separator())
                continue
            }

            guard let title = item["title"] as? String else { continue }
            let key = item["key"] as? String ?? ""
            let id = item["id"] as? String ?? title

            let menuItem = NSMenuItem(title: title, action: #selector(menuItemClicked(_:)), keyEquivalent: key)
            menuItem.target = self
            menuItem.representedObject = id

            if let disabled = item["disabled"] as? Bool, disabled {
                menuItem.isEnabled = false
            }

            menu.addItem(menuItem)
        }
    }

    @objc private func menuItemClicked(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        dispatcher?.dispatchGlobalEvent("menu:itemClick", payload: ["id": id, "title": sender.title])
    }
}
