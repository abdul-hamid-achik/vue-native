import AppKit
import ObjectiveC

/// Factory for VToolbar — macOS-specific toolbar component.
/// Creates a placeholder FlippedView. When the view is added to a window,
/// an NSToolbar is created and attached to the window.
///
/// Props:
///   - items: [{ id, label, icon?, action? }]
///   - displayMode: "iconOnly" | "labelOnly" | "iconAndLabel"
///   - showsBaselineSeparator: Bool
///
/// Events:
///   - itemClick -> { id }
final class VToolbarFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var toolbarDelegateKey: UInt8 = 0
    private static var toolbarItemsKey: UInt8 = 0
    private static var toolbarKey: UInt8 = 0
    private static var itemClickHandlerKey: UInt8 = 0
    private static var displayModeKey: UInt8 = 0
    private static var showsBaselineSeparatorKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let view = ToolbarPlaceholderView()
        view.ensureLayoutNode()
        view.onWindowChange = { [weak self, weak view] oldWindow, newWindow in
            guard let self, let view else { return }

            if let oldWindow,
               let installedToolbar = objc_getAssociatedObject(
                   view, &VToolbarFactory.toolbarKey
               ) as? NSToolbar,
               oldWindow.toolbar === installedToolbar {
                oldWindow.toolbar = nil
            }

            if newWindow != nil {
                self.rebuildToolbar(for: view)
            } else {
                objc_setAssociatedObject(
                    view, &VToolbarFactory.toolbarKey,
                    nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                objc_setAssociatedObject(
                    view, &VToolbarFactory.toolbarDelegateKey,
                    nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        }
        return view
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        switch key {
        case "items":
            guard let items = value as? [[String: Any]] else { return }
            objc_setAssociatedObject(
                view, &VToolbarFactory.toolbarItemsKey,
                items, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            rebuildToolbar(for: view)

        case "displayMode":
            objc_setAssociatedObject(
                view, &VToolbarFactory.displayModeKey,
                value as? String, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            updateExistingToolbar(for: view)

        case "showsBaselineSeparator":
            objc_setAssociatedObject(
                view, &VToolbarFactory.showsBaselineSeparatorKey,
                value as? Bool, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            updateExistingToolbar(for: view)

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        switch event {
        case "itemClick":
            objc_setAssociatedObject(
                view, &VToolbarFactory.itemClickHandlerKey,
                handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            updateExistingToolbar(for: view)

        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        switch event {
        case "itemClick":
            objc_setAssociatedObject(
                view, &VToolbarFactory.itemClickHandlerKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            updateExistingToolbar(for: view)

        default:
            break
        }
    }

    // MARK: - Toolbar management

    private func rebuildToolbar(for view: NSView) {
        guard let window = view.window else { return }

        let items = objc_getAssociatedObject(
            view, &VToolbarFactory.toolbarItemsKey
        ) as? [[String: Any]] ?? []

        let itemClickHandler: ((Any?) -> Void)? = {
            let stored = objc_getAssociatedObject(
                view, &VToolbarFactory.itemClickHandlerKey
            )
            return stored as? (Any?) -> Void
        }()

        let delegate = ToolbarDelegate(items: items, onItemClick: itemClickHandler)
        objc_setAssociatedObject(
            view, &VToolbarFactory.toolbarDelegateKey,
            delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        let toolbar = NSToolbar(identifier: "VueNativeToolbar-\(ObjectIdentifier(view).hashValue)")
        toolbar.delegate = delegate
        applyStoredOptions(to: toolbar, for: view)

        objc_setAssociatedObject(
            view, &VToolbarFactory.toolbarKey,
            toolbar, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        window.toolbar = toolbar
    }

    private func updateExistingToolbar(for view: NSView) {
        guard objc_getAssociatedObject(
            view, &VToolbarFactory.toolbarKey
        ) is NSToolbar else {
            return
        }
        rebuildToolbar(for: view)
    }

    private func applyStoredOptions(to toolbar: NSToolbar, for view: NSView) {
        let mode = objc_getAssociatedObject(
            view, &VToolbarFactory.displayModeKey
        ) as? String

        switch mode {
        case "iconOnly":
            toolbar.displayMode = .iconOnly
        case "labelOnly":
            toolbar.displayMode = .labelOnly
        case "iconAndLabel", nil:
            toolbar.displayMode = .iconAndLabel
        default:
            toolbar.displayMode = .default
        }

        let showsBaselineSeparator = (
            objc_getAssociatedObject(
                view, &VToolbarFactory.showsBaselineSeparatorKey
            ) as? Bool
        ) ?? true

        if #unavailable(macOS 15.0) {
            toolbar.showsBaselineSeparator = showsBaselineSeparator
        }
    }
}

// MARK: - ToolbarPlaceholderView

private final class ToolbarPlaceholderView: FlippedView {
    var onWindowChange: ((NSWindow?, NSWindow?) -> Void)?
    private weak var previouslyAttachedWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let oldWindow = previouslyAttachedWindow
        let newWindow = window
        guard oldWindow !== newWindow else { return }
        previouslyAttachedWindow = newWindow
        onWindowChange?(oldWindow, newWindow)
    }
}

// MARK: - ToolbarDelegate

private final class ToolbarDelegate: NSObject, NSToolbarDelegate {

    private let items: [[String: Any]]
    private let onItemClick: ((Any?) -> Void)?

    init(items: [[String: Any]], onItemClick: ((Any?) -> Void)?) {
        self.items = items
        self.onItemClick = onItemClick
        super.init()
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return items.map { item in
            NSToolbarItem.Identifier(item["id"] as? String ?? UUID().uuidString)
        } + [.flexibleSpace, .space]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return items.map { item in
            NSToolbarItem.Identifier(item["id"] as? String ?? UUID().uuidString)
        }
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let itemData = items.first(where: {
            ($0["id"] as? String) == itemIdentifier.rawValue
        }) else {
            return nil
        }

        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.label = itemData["label"] as? String ?? ""
        toolbarItem.toolTip = itemData["label"] as? String

        if let iconName = itemData["icon"] as? String {
            if let systemImage = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
                toolbarItem.image = systemImage
            } else {
                toolbarItem.image = NSImage(named: iconName)
            }
        }

        toolbarItem.target = self
        toolbarItem.action = #selector(toolbarItemClicked(_:))

        return toolbarItem
    }

    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        onItemClick?(["id": sender.itemIdentifier.rawValue])
    }
}
