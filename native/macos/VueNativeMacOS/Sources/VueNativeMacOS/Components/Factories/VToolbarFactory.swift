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

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let view = FlippedView()
        view.ensureLayoutNode()
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
            guard let toolbar = objc_getAssociatedObject(
                view, &VToolbarFactory.toolbarKey
            ) as? NSToolbar else { return }

            if let mode = value as? String {
                switch mode {
                case "iconOnly":
                    toolbar.displayMode = .iconOnly
                case "labelOnly":
                    toolbar.displayMode = .labelOnly
                case "iconAndLabel":
                    toolbar.displayMode = .iconAndLabel
                default:
                    toolbar.displayMode = .default
                }
            }

        case "showsBaselineSeparator":
            guard let toolbar = objc_getAssociatedObject(
                view, &VToolbarFactory.toolbarKey
            ) as? NSToolbar else { return }
            toolbar.showsBaselineSeparator = (value as? Bool) ?? true

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

        default:
            break
        }
    }

    // MARK: - Toolbar management

    private func rebuildToolbar(for view: NSView) {
        guard let window = view.window else {
            // View not yet in a window — defer until it appears.
            // We'll use viewDidMoveToWindow in the observation.
            setupWindowObserver(for: view)
            return
        }

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
        toolbar.displayMode = .default
        toolbar.showsBaselineSeparator = true

        objc_setAssociatedObject(
            view, &VToolbarFactory.toolbarKey,
            toolbar, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        window.toolbar = toolbar
    }

    private func setupWindowObserver(for view: NSView) {
        // Observe when the view moves to a window
        let observer = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak view] _ in
            guard let self = self, let view = view, view.window != nil else { return }
            self.rebuildToolbar(for: view)
        }
        // Store observer to keep it alive; will be replaced on next call
        objc_setAssociatedObject(
            view, &VToolbarFactory.toolbarDelegateKey,
            observer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
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
