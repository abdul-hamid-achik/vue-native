import AppKit
import VueNativeShared

/// macOS-only module for menu bar control.
///
/// Methods:
///   - setAppMenu(items: [{ title, items: [{ title, key?, modifiers?, id?, separator?, disabled? }] }])
///   - showContextMenu(items: [{ title, key?, modifiers?, id?, separator?, disabled? }])
///
/// `setAppMenu` *merges* into the installed main menu: a top-level entry whose
/// title matches an existing menu replaces that menu's items, anything else is
/// appended. It never assigns a fresh `NSApp.mainMenu`, because that would wipe
/// the standard App/Edit/Window menus `VueNativeAppDelegate` installs — and with
/// them every key equivalent (Cmd+Q, Cmd+C/V/X/A), which AppKit only routes
/// through the main menu.
///
/// Events dispatched:
///   - menu:itemClick { id, title }
final class MenuModule: NativeModule {
    let moduleName = "Menu"
    private weak var dispatcher: NativeEventDispatcher?

    /// Retains the target-action proxies for every menu item this module built.
    /// `NSMenuItem.target` is `weak`, so without this the proxies would die
    /// immediately and no click would ever be delivered.
    private var itemProxies: [MenuActionProxy] = []

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
                self?.mergeIntoMainMenu(items: items)
                callback(nil, nil)

            case "showContextMenu":
                guard let items = args.first as? [[String: Any]] else {
                    callback(nil, "Invalid args")
                    return
                }
                let menu = NSMenu()
                menu.autoenablesItems = false
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

    func destroy() {
        itemProxies.removeAll()
        dispatcher = nil
    }

    // MARK: - Merging

    /// Merge a declarative menu description into `NSApp.mainMenu`.
    ///
    /// Falls back to installing the standard menu first when nothing is
    /// installed yet (a host that never went through `VueNativeAppDelegate`),
    /// so `setAppMenu` can never leave the app without its key equivalents.
    private func mergeIntoMainMenu(items: [[String: Any]]) {
        if NSApp.mainMenu == nil {
            NSApp.mainMenu = VueNativeAppDelegate.standardMainMenu()
        }
        guard let mainMenu = NSApp.mainMenu else { return }

        for item in items {
            guard let title = item["title"] as? String else { continue }
            let children = item["items"] as? [[String: Any]] ?? []

            let menuItem: NSMenuItem
            if let existing = mainMenu.items.first(where: { $0.title == title }) {
                menuItem = existing
            } else {
                menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                mainMenu.addItem(menuItem)
            }

            let submenu = menuItem.submenu ?? NSMenu(title: title)
            submenu.title = title
            submenu.removeAllItems()
            submenu.autoenablesItems = false
            addMenuItems(children, to: submenu)
            menuItem.submenu = submenu
        }
    }

    private func addMenuItems(_ items: [[String: Any]], to menu: NSMenu) {
        for item in items {
            if let separator = item["separator"] as? Bool, separator {
                menu.addItem(.separator())
                continue
            }

            guard let title = item["title"] as? String else { continue }
            let key = (item["key"] as? String ?? "").lowercased()
            let id = item["id"] as? String ?? title

            let proxy = MenuActionProxy()
            proxy.itemID = id
            proxy.onClick = { [weak self] itemID, itemTitle in
                self?.dispatcher?.dispatchGlobalEvent(
                    "menu:itemClick",
                    payload: ["id": itemID, "title": itemTitle]
                )
            }
            itemProxies.append(proxy)

            let menuItem = NSMenuItem(
                title: title,
                action: #selector(MenuActionProxy.menuItemClicked(_:)),
                keyEquivalent: key
            )
            menuItem.target = proxy
            menuItem.representedObject = id
            // Without the mask only bare (unmodified) equivalents are
            // expressible, so Shift/Option/Command combinations silently
            // degraded to no shortcut at all.
            menuItem.keyEquivalentModifierMask = MenuModule.modifierMask(from: item["modifiers"] ?? item["modifierFlags"])

            if let disabled = item["disabled"] as? Bool, disabled {
                menuItem.isEnabled = false
            }

            menu.addItem(menuItem)
        }
    }

    // MARK: - Modifier parsing

    /// Parse a `modifiers` prop into an `NSEvent.ModifierFlags` mask.
    ///
    /// Accepts a single string (`"cmd"`), a combined string with `+`, `-`, `,`
    /// or space separators (`"cmd+shift"`), an array of strings
    /// (`["cmd", "shift"]`), or a raw `NSEvent.ModifierFlags` value. Recognised
    /// names: `cmd`/`command`/`⌘`, `shift`/`⇧`, `opt`/`option`/`alt`/`⌥`,
    /// `ctrl`/`control`/`⌃`, `fn`. `nil` yields `.command`, the AppKit default
    /// for a menu item with a key equivalent.
    static func modifierMask(from value: Any?) -> NSEvent.ModifierFlags {
        var names: [String] = []
        switch value {
        case let str as String:
            names = str
                .lowercased()
                .components(separatedBy: CharacterSet(charactersIn: "+-,& \t"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        case let arr as [Any]:
            names = arr.compactMap { ($0 as? String)?.lowercased() }
        case let num as Int:
            return NSEvent.ModifierFlags(rawValue: UInt(num))
        case let num as NSNumber:
            return NSEvent.ModifierFlags(rawValue: UInt(num.uint64Value))
        case nil:
            return .command
        default:
            return .command
        }
        guard !names.isEmpty else { return [] }

        var mask = NSEvent.ModifierFlags()
        for name in names {
            switch name {
            case "cmd", "command", "meta", "⌘": mask.insert(.command)
            case "shift", "⇧": mask.insert(.shift)
            case "opt", "option", "alt", "⌥": mask.insert(.option)
            case "ctrl", "control", "⌃": mask.insert(.control)
            case "fn": mask.insert(.function)
            case "none", "": break
            default:
                #if DEBUG
                NSLog("[VueNative macOS] MenuModule: ignoring unknown key modifier '\(name)'")
                #endif
            }
        }
        return mask
    }
}

// MARK: - MenuActionProxy

/// Target-action proxy for `NSMenuItem`, following the pattern every other
/// action site in this package uses (`ActionSheetProxy`, `CheckboxActionProxy`,
/// `SliderActionProxy`, `ToolbarDelegate`, ...).
///
/// `MenuModule` is a pure-Swift `NativeModule` with no `NSObject` base, so it
/// cannot be an `NSMenuItem.target` under the lifetime guarantees the rest of
/// the package relies on: `target` is a `weak` ObjC reference and a plain Swift
/// class is not managed by the ObjC weak-reference table in the same way. The
/// proxy is a real ObjC object, retained by the module for as long as the menu
/// item lives.
final class MenuActionProxy: NSObject {

    /// Fallback id, used when the menu item carries no `representedObject`.
    var itemID: String = ""

    /// Invoked with `(id, title)` when the item is clicked.
    var onClick: ((String, String) -> Void)?

    @objc func menuItemClicked(_ sender: NSMenuItem) {
        let id = (sender.representedObject as? String) ?? itemID
        onClick?(id, sender.title)
    }
}
