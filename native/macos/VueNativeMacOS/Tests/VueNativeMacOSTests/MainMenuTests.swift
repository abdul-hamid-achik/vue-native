#if canImport(AppKit)
import AppKit
import XCTest
import VueNativeShared
@testable import VueNativeMacOS

/// Coverage for the macOS app-shell menu bar:
/// - a programmatic `NSApplication` has no nib, so `NSApp.mainMenu` used to stay
///   `nil` and the app had an empty menu bar — which also meant Cmd+Q did not
///   quit and Cmd+C/V/X/A never reached a focused `VInput`, because AppKit
///   routes key equivalents through the main menu;
/// - `MenuModule.setAppMenu` used to *replace* `NSApp.mainMenu`, wiping those
///   standard menus;
/// - menu items never carried a `keyEquivalentModifierMask`, so Shift/Option/Cmd
///   combinations were inexpressible.
@MainActor
final class MainMenuTests: XCTestCase {

    private var savedMainMenu: NSMenu?
    private var savedWindowsMenu: NSMenu?
    private var savedHelpMenu: NSMenu?
    private var savedServicesMenu: NSMenu?

    override func setUp() {
        super.setUp()
        savedMainMenu = NSApp.mainMenu
        savedWindowsMenu = NSApp.windowsMenu
        savedHelpMenu = NSApp.helpMenu
        savedServicesMenu = NSApp.servicesMenu
    }

    override func tearDown() {
        NSApp.mainMenu = savedMainMenu
        NSApp.windowsMenu = savedWindowsMenu
        NSApp.helpMenu = savedHelpMenu
        NSApp.servicesMenu = savedServicesMenu
        super.tearDown()
    }

    // MARK: - Helpers

    private func submenu(of mainMenu: NSMenu, titled title: String) -> NSMenu? {
        return mainMenu.items.first { $0.title == title }?.submenu
    }

    private func item(in menu: NSMenu?, titled title: String) -> NSMenuItem? {
        return menu?.items.first { $0.title == title }
    }

    /// Run the main run loop until `predicate` holds or the timeout elapses.
    private func spin(until predicate: () -> Bool, timeout: TimeInterval = 2.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        return predicate()
    }

    private final class RecordingDispatcher: NativeEventDispatcher {
        var events: [(name: String, payload: [String: Any])] = []
        func dispatchGlobalEvent(_ eventName: String, payload: [String: Any]) {
            events.append((eventName, payload))
        }
    }

    // MARK: - #4 Standard main menu

    func testStandardMainMenuHasTheCanonicalMenus() {
        let menu = VueNativeAppDelegate.standardMainMenu()

        // First top-level item is the application menu; AppKit ignores its title.
        XCTAssertEqual(menu.items.count, 5, "App, Edit, View, Window, Help")
        XCTAssertNotNil(menu.items[0].submenu, "the first item must be the application menu")
        XCTAssertEqual(menu.items.dropFirst().map(\.title), ["Edit", "View", "Window", "Help"])
    }

    /// Without a Quit item carrying Cmd+Q, `NSApp` never terminates from the
    /// keyboard — the concrete symptom of the missing main menu.
    func testStandardMainMenuQuitIsCmdQ() {
        let appMenu = VueNativeAppDelegate.standardMainMenu().items[0].submenu
        guard let quit = item(in: appMenu, titled: "Quit") else {
            return XCTFail("application menu must contain Quit")
        }
        XCTAssertEqual(quit.keyEquivalent, "q")
        XCTAssertEqual(quit.keyEquivalentModifierMask, .command)
        XCTAssertEqual(quit.action, #selector(NSApplication.terminate(_:)))
        XCTAssertNil(quit.target, "nil target routes through the responder chain")
    }

    /// Cmd+C/V/X/A only work if they exist in the main menu with a nil target, so
    /// AppKit walks the responder chain down to the focused field editor.
    func testStandardMainMenuEditHasResponderChainClipboardShortcuts() {
        let menu = VueNativeAppDelegate.standardMainMenu()
        let edit = submenu(of: menu, titled: "Edit")

        let expectations: [(String, String, Selector)] = [
            ("Cut", "x", #selector(NSText.cut(_:))),
            ("Copy", "c", #selector(NSText.copy(_:))),
            ("Paste", "v", #selector(NSText.paste(_:))),
            ("Select All", "a", #selector(NSText.selectAll(_:))),
        ]
        for (title, key, action) in expectations {
            guard let menuItem = item(in: edit, titled: title) else {
                XCTFail("Edit menu must contain \(title)")
                continue
            }
            XCTAssertEqual(menuItem.keyEquivalent, key, "\(title) shortcut")
            XCTAssertEqual(menuItem.keyEquivalentModifierMask, .command, "\(title) must be Cmd+\(key)")
            XCTAssertEqual(menuItem.action, action)
            XCTAssertNil(menuItem.target, "\(title) must travel the responder chain")
        }

        XCTAssertEqual(item(in: edit, titled: "Undo")?.keyEquivalent, "z")
        XCTAssertEqual(item(in: edit, titled: "Redo")?.keyEquivalentModifierMask,
                       NSEvent.ModifierFlags([.command, .shift]))
    }

    func testStandardMainMenuWiresWindowAndHelpMenus() {
        let menu = VueNativeAppDelegate.standardMainMenu()
        XCTAssertNotNil(NSApp.windowsMenu, "AppKit needs windowsMenu to keep the Window menu in sync")
        XCTAssertNotNil(NSApp.helpMenu)
        XCTAssertNotNil(NSApp.servicesMenu)
        XCTAssertEqual(item(in: submenu(of: menu, titled: "Window"), titled: "Minimize")?.keyEquivalent, "m")
        XCTAssertEqual(item(in: submenu(of: menu, titled: "Window"), titled: "Close")?.keyEquivalent, "w")
    }

    func testInstallMainMenuIfNeededInstallsWhenAbsent() {
        NSApp.mainMenu = nil
        XCTAssertTrue(VueNativeAppDelegate.installMainMenuIfNeeded(), "an empty menu bar must be filled in")
        XCTAssertNotNil(NSApp.mainMenu)
        XCTAssertNotNil(submenu(of: NSApp.mainMenu!, titled: "Edit"))
    }

    /// An app that builds its own menu must win — the installer must not replace it.
    func testInstallMainMenuIfNeededDoesNotReplaceAnExistingMenu() {
        let custom = NSMenu()
        let customItem = NSMenuItem(title: "Custom", action: nil, keyEquivalent: "")
        custom.addItem(customItem)
        NSApp.mainMenu = custom

        XCTAssertFalse(VueNativeAppDelegate.installMainMenuIfNeeded())
        XCTAssertTrue(NSApp.mainMenu === custom, "a pre-installed main menu must be left alone")
    }

    /// `makeMainMenu()` is the documented override point.
    func testMakeMainMenuIsOverridable() {
        final class CustomDelegate: VueNativeAppDelegate {
            let replacement = NSMenu()
            override func makeMainMenu() -> NSMenu { replacement }
        }
        let delegate = CustomDelegate()
        XCTAssertTrue(delegate.makeMainMenu() === delegate.replacement)
        XCTAssertFalse(delegate.makeMainMenu() === VueNativeAppDelegate.standardMainMenu(),
                       "the subclass replaces the standard menu")
    }

    // MARK: - #5 setAppMenu merges instead of replacing

    func testSetAppMenuMergesWithoutWipingStandardMenus() {
        NSApp.mainMenu = VueNativeAppDelegate.standardMainMenu()
        let dispatcher = RecordingDispatcher()
        let module = MenuModule(dispatcher: dispatcher)

        module.invoke(method: "setAppMenu", args: [[
            ["title": "File", "items": [["title": "Open", "id": "open"]]],
        ]]) { _, _ in }
        XCTAssertTrue(spin { item(in: NSApp.mainMenu, titled: "File") != nil },
                      "setAppMenu must add the File menu")

        let mainMenu = NSApp.mainMenu!
        XCTAssertNotNil(submenu(of: mainMenu, titled: "Edit"), "the standard Edit menu must survive")
        XCTAssertNotNil(submenu(of: mainMenu, titled: "Window"), "the standard Window menu must survive")
        XCTAssertEqual(item(in: submenu(of: mainMenu, titled: "Edit"), titled: "Copy")?.keyEquivalent, "c",
                       "standard key equivalents must survive")
        XCTAssertEqual(item(in: submenu(of: mainMenu, titled: "File"), titled: "Open")?.representedObject as? String, "open")
    }

    /// A second call for the same title replaces that menu's items instead of
    /// appending a duplicate top-level entry.
    func testSetAppMenuReplacesMatchingTopLevelMenuInPlace() {
        NSApp.mainMenu = VueNativeAppDelegate.standardMainMenu()
        let module = MenuModule(dispatcher: RecordingDispatcher())

        module.invoke(method: "setAppMenu", args: [[
            ["title": "File", "items": [["title": "Open", "id": "open"]]],
        ]]) { _, _ in }
        XCTAssertTrue(spin { item(in: NSApp.mainMenu, titled: "File") != nil })

        module.invoke(method: "setAppMenu", args: [[
            ["title": "File", "items": [["title": "Export", "id": "export"]]],
        ]]) { _, _ in }
        XCTAssertTrue(spin { item(in: submenu(of: NSApp.mainMenu!, titled: "File"), titled: "Export") != nil })

        let fileItems = NSApp.mainMenu!.items.filter { $0.title == "File" }
        XCTAssertEqual(fileItems.count, 1, "must merge into the existing top-level entry, not append")
        XCTAssertNil(item(in: submenu(of: NSApp.mainMenu!, titled: "File"), titled: "Open"),
                     "the previous items must be replaced")
    }

    /// `setAppMenu` on a host that never installed a menu must not leave the app
    /// without its key equivalents.
    func testSetAppMenuInstallsStandardMenuWhenNoneExists() {
        NSApp.mainMenu = nil
        let module = MenuModule(dispatcher: RecordingDispatcher())

        module.invoke(method: "setAppMenu", args: [[
            ["title": "File", "items": [["title": "Open", "id": "open"]]],
        ]]) { _, _ in }

        XCTAssertTrue(spin { NSApp.mainMenu != nil })
        XCTAssertNotNil(submenu(of: NSApp.mainMenu!, titled: "Edit"),
                        "the standard menus must be installed as a base")
        XCTAssertNotNil(item(in: NSApp.mainMenu, titled: "File"))
    }

    // MARK: - #5 key equivalent modifiers

    func testSetAppMenuAppliesKeyEquivalentModifierMask() {
        NSApp.mainMenu = VueNativeAppDelegate.standardMainMenu()
        let module = MenuModule(dispatcher: RecordingDispatcher())

        module.invoke(method: "setAppMenu", args: [[
            ["title": "File", "items": [
                ["title": "Save", "key": "S", "modifiers": "cmd+shift", "id": "save"],
                ["title": "Plain", "key": "p", "id": "plain"],
                ["title": "Fancy", "key": "f", "modifiers": ["cmd", "option", "shift"], "id": "fancy"],
            ]],
        ]]) { _, _ in }
        XCTAssertTrue(spin { item(in: submenu(of: NSApp.mainMenu!, titled: "File"), titled: "Save") != nil })

        let file = submenu(of: NSApp.mainMenu!, titled: "File")
        XCTAssertEqual(item(in: file, titled: "Save")?.keyEquivalent, "s", "key equivalents are lowercased; shift lives in the mask")
        XCTAssertEqual(item(in: file, titled: "Save")?.keyEquivalentModifierMask, NSEvent.ModifierFlags([.command, .shift]))
        XCTAssertEqual(item(in: file, titled: "Plain")?.keyEquivalentModifierMask, .command, "AppKit's default")
        XCTAssertEqual(item(in: file, titled: "Fancy")?.keyEquivalentModifierMask,
                       NSEvent.ModifierFlags([.command, .option, .shift]))
    }

    func testModifierMaskParsing() {
        XCTAssertEqual(MenuModule.modifierMask(from: "cmd"), .command)
        XCTAssertEqual(MenuModule.modifierMask(from: "command+shift"), NSEvent.ModifierFlags([.command, .shift]))
        XCTAssertEqual(MenuModule.modifierMask(from: "opt-ctrl"), NSEvent.ModifierFlags([.option, .control]))
        XCTAssertEqual(MenuModule.modifierMask(from: ["shift", "alt"]), NSEvent.ModifierFlags([.shift, .option]))
        XCTAssertEqual(MenuModule.modifierMask(from: "none"), [], "an explicit empty mask is expressible")
        XCTAssertEqual(MenuModule.modifierMask(from: nil), .command, "absent modifiers default to Cmd")
    }

    // MARK: - #6 the click actually reaches JS

    /// There was no MenuModule test at all, and `MenuModule` is a pure-Swift
    /// `NativeModule` (no `NSObject` base) while `NSMenuItem.target` is a weak
    /// ObjC reference. This drives the real target-action path.
    func testMenuItemClickDispatchesEventToJS() {
        NSApp.mainMenu = VueNativeAppDelegate.standardMainMenu()
        let dispatcher = RecordingDispatcher()
        let module = MenuModule(dispatcher: dispatcher)

        module.invoke(method: "setAppMenu", args: [[
            ["title": "File", "items": [["title": "Open", "id": "open-file"]]],
        ]]) { _, _ in }
        XCTAssertTrue(spin { item(in: submenu(of: NSApp.mainMenu!, titled: "File"), titled: "Open") != nil })

        guard let menuItem = item(in: submenu(of: NSApp.mainMenu!, titled: "File"), titled: "Open") else {
            return XCTFail("menu item missing")
        }
        XCTAssertNotNil(menuItem.target, "the item must have a target to dispatch to")
        XCTAssertTrue(menuItem.target is MenuActionProxy,
                      "the target must be the NSObject proxy the rest of the package uses")
        XCTAssertTrue(menuItem.target!.responds(to: menuItem.action!),
                      "the proxy must answer the item's action selector")

        // The exact path AppKit uses when the user clicks the item.
        XCTAssertTrue(NSApp.sendAction(menuItem.action!, to: menuItem.target, from: menuItem))

        XCTAssertTrue(spin { !dispatcher.events.isEmpty }, "menu:itemClick must reach the dispatcher")
        XCTAssertEqual(dispatcher.events.first?.name, "menu:itemClick")
        XCTAssertEqual(dispatcher.events.first?.payload["id"] as? String, "open-file")
        XCTAssertEqual(dispatcher.events.first?.payload["title"] as? String, "Open")
    }

    /// `id` defaults to the title, and separators/disabled items must not break
    /// the build.
    func testMenuItemDefaultsAndSeparators() {
        NSApp.mainMenu = VueNativeAppDelegate.standardMainMenu()
        let dispatcher = RecordingDispatcher()
        let module = MenuModule(dispatcher: dispatcher)

        module.invoke(method: "setAppMenu", args: [[
            ["title": "Tools", "items": [
                ["title": "Reload"],
                ["separator": true],
                ["title": "Locked", "id": "locked", "disabled": true],
            ]],
        ]]) { _, _ in }
        XCTAssertTrue(spin { item(in: NSApp.mainMenu, titled: "Tools") != nil })

        let tools = submenu(of: NSApp.mainMenu!, titled: "Tools")
        XCTAssertEqual(tools?.items.count, 3)
        XCTAssertTrue(tools?.items[1].isSeparatorItem ?? false)
        XCTAssertFalse(tools?.items[2].isEnabled ?? true, "`disabled: true` must disable the item")

        guard let reload = item(in: tools, titled: "Reload") else { return XCTFail("missing item") }
        XCTAssertTrue(NSApp.sendAction(reload.action!, to: reload.target, from: reload))
        XCTAssertTrue(spin { !dispatcher.events.isEmpty })
        XCTAssertEqual(dispatcher.events.first?.payload["id"] as? String, "Reload", "id defaults to the title")
    }

    /// Unknown methods must report an error rather than silently succeeding.
    func testUnknownMethodReportsError() {
        let module = MenuModule(dispatcher: RecordingDispatcher())
        var captured: String?
        module.invoke(method: "bogus", args: []) { _, error in captured = error }
        XCTAssertTrue(spin { captured != nil })
        XCTAssertTrue(captured?.contains("bogus") ?? false)
    }
}
#endif
