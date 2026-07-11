import AppKit
import ObjectiveC

/// Factory for VModal — presents content in a modal panel or sheet.
/// The view itself is a zero-size hidden placeholder in the native tree.
/// Its children are moved into an NSPanel when visible=true.
final class VModalFactory: NativeComponentFactory {

    typealias SheetCompletion = (NSApplication.ModalResponse) -> Void

    private let sheetPresenter: (NSWindow, @escaping SheetCompletion) -> Bool
    private let sheetDismissal: (NSWindow) -> Void
    private let panelPresenter: (NSPanel, String) -> Void
    private let panelDismissal: (NSPanel, String) -> Void

    init(
        sheetPresenter: ((NSWindow, @escaping SheetCompletion) -> Bool)? = nil,
        sheetDismissal: ((NSWindow) -> Void)? = nil,
        panelPresenter: ((NSPanel, String) -> Void)? = nil,
        panelDismissal: ((NSPanel, String) -> Void)? = nil
    ) {
        self.sheetPresenter = sheetPresenter ?? VModalPresentation.presentSheet
        self.sheetDismissal = sheetDismissal ?? VModalPresentation.dismissSheet
        self.panelPresenter = panelPresenter ?? VModalPresentation.presentPanel
        self.panelDismissal = panelDismissal ?? VModalPresentation.dismissPanel
    }

    // MARK: - Associated object keys

    private static var panelKey: UInt8 = 0
    private static var visibleKey: UInt8 = 1
    private static var animationTypeKey: UInt8 = 2
    private static var transparentKey: UInt8 = 3
    private static var presentationStyleKey: UInt8 = 4
    private static var onDismissKey: UInt8 = 5
    private static var onShowKey: UInt8 = 6
    private static var overlayKey: UInt8 = 7
    private static var panelDelegateKey: UInt8 = 8

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let placeholder = FlippedView()
        placeholder.isHidden = true
        let node = placeholder.ensureLayoutNode()
        node.width = .points(0)
        node.height = .points(0)
        return placeholder
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        switch key {
        case "visible":
            let visible = (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? false
            let wasVisible = objc_getAssociatedObject(view, &VModalFactory.visibleKey) as? Bool ?? false
            objc_setAssociatedObject(view, &VModalFactory.visibleKey, visible, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if visible && !wasVisible {
                showModal(for: view)
            } else if !visible && wasVisible {
                hideModal(for: view)
            }

        case "animationType":
            objc_setAssociatedObject(
                view, &VModalFactory.animationTypeKey,
                value as? String ?? "none",
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "transparent":
            let transparent = (value as? Bool) ?? false
            objc_setAssociatedObject(
                view, &VModalFactory.transparentKey,
                transparent,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "presentationStyle":
            objc_setAssociatedObject(
                view, &VModalFactory.presentationStyleKey,
                value as? String ?? "modal",
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            // Apply public VModal styles to the panel content rather than the
            // hidden placeholder in the logical view tree.
            let overlay = getOrCreateOverlay(for: view)
            StyleEngine.apply(key: key, value: value, to: overlay)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        switch event {
        case "dismiss":
            objc_setAssociatedObject(
                view, &VModalFactory.onDismissKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        case "show":
            objc_setAssociatedObject(
                view, &VModalFactory.onShowKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        switch event {
        case "dismiss":
            objc_setAssociatedObject(view, &VModalFactory.onDismissKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "show":
            objc_setAssociatedObject(view, &VModalFactory.onShowKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default:
            break
        }
    }

    func destroyView(view: NSView) {
        // Clear callbacks before ending a sheet so its completion handler cannot
        // dispatch a dismiss event for a component that no longer exists.
        objc_setAssociatedObject(
            view, &VModalFactory.onDismissKey,
            nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            view, &VModalFactory.onShowKey,
            nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        if let panel = objc_getAssociatedObject(
            view, &VModalFactory.panelKey
        ) as? NSWindow {
            if let floatingPanel = panel as? NSPanel {
                let animationType = objc_getAssociatedObject(
                    view, &VModalFactory.animationTypeKey
                ) as? String ?? "none"
                panelDismissal(floatingPanel, animationType)
            } else {
                sheetDismissal(panel)
            }
            panel.contentView = nil
            panel.orderOut(nil)
            panel.close()
            panel.delegate = nil
        }

        if let overlay = objc_getAssociatedObject(
            view, &VModalFactory.overlayKey
        ) as? NSView {
            ExternalLayoutRootRegistry.unregister(overlay)
            overlay.removeFromSuperview()
            for child in overlay.subviews {
                child.removeFromSuperview()
            }
        }

        objc_setAssociatedObject(
            view, &VModalFactory.panelKey,
            nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            view, &VModalFactory.overlayKey,
            nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            view, &VModalFactory.visibleKey,
            nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            view, &VModalFactory.panelDelegateKey,
            nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    // Custom child management: route children to the overlay container
    func insertChild(_ child: NSView, into parent: NSView, before anchor: NSView?) {
        let overlay = getOrCreateOverlay(for: parent)
        if let anchor = anchor, overlay.subviews.contains(anchor) {
            overlay.addSubview(child, positioned: .below, relativeTo: anchor)
        } else {
            overlay.addSubview(child)
        }
        child.ensureLayoutNode()
    }

    func removeChild(_ child: NSView, from parent: NSView) {
        child.removeFromSuperview()
    }
}

// MARK: - Private helpers

private extension VModalFactory {
    private func getOrCreateOverlay(for placeholder: NSView) -> ModalContentView {
        if let existing = objc_getAssociatedObject(
            placeholder,
            &VModalFactory.overlayKey
        ) as? ModalContentView {
            return existing
        }
        let overlay = ModalContentView()
        overlay.wantsLayer = true
        let node = overlay.ensureLayoutNode()
        node.flexGrow = 1
        objc_setAssociatedObject(
            placeholder, &VModalFactory.overlayKey,
            overlay, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return overlay
    }

    private func showModal(for placeholder: NSView) {
        let style = objc_getAssociatedObject(placeholder, &VModalFactory.presentationStyleKey) as? String ?? "modal"
        let overlay = getOrCreateOverlay(for: placeholder)
        let didPresent: Bool
        if style == "sheet" {
            didPresent = presentSheet(for: placeholder, overlay: overlay)
        } else {
            presentPanel(for: placeholder, overlay: overlay)
            didPresent = true
        }
        if didPresent {
            fireEvent(for: placeholder, key: &VModalFactory.onShowKey)
        }
    }

    private func presentSheet(for placeholder: NSView, overlay: ModalContentView) -> Bool {
        let sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        sheetWindow.contentView = overlay
        ExternalLayoutRootRegistry.register(overlay)
        overlay.layoutManagedContent()
        objc_setAssociatedObject(
            placeholder, &VModalFactory.panelKey,
            sheetWindow, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        let completion: SheetCompletion = { [weak placeholder] _ in
            guard let placeholder,
                  let activePanel = objc_getAssociatedObject(
                    placeholder, &VModalFactory.panelKey
                  ) as? NSWindow,
                  activePanel === sheetWindow else { return }
            self.finishSheet(sheetWindow, overlay: overlay, for: placeholder)
            self.fireEvent(for: placeholder, key: &VModalFactory.onDismissKey)
        }
        guard sheetPresenter(sheetWindow, completion) else {
            finishSheet(sheetWindow, overlay: overlay, for: placeholder)
            return false
        }
        return true
    }

    private func finishSheet(
        _ sheetWindow: NSWindow,
        overlay: ModalContentView,
        for placeholder: NSView
    ) {
        objc_setAssociatedObject(
            placeholder, &VModalFactory.panelKey,
            nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            placeholder, &VModalFactory.visibleKey,
            false, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        sheetWindow.contentView = nil
        ExternalLayoutRootRegistry.unregister(overlay)
        overlay.removeFromSuperview()
    }

    private func presentPanel(for placeholder: NSView, overlay: ModalContentView) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        let transparent = objc_getAssociatedObject(
            placeholder, &VModalFactory.transparentKey
        ) as? Bool ?? false
        panel.isOpaque = !transparent
        panel.backgroundColor = transparent ? .clear : NSColor(white: 0.95, alpha: 1)
        panel.contentView = overlay
        ExternalLayoutRootRegistry.register(overlay)
        overlay.layoutManagedContent()
        objc_setAssociatedObject(
            placeholder, &VModalFactory.panelKey,
            panel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        installCloseDelegate(on: panel, for: placeholder)

        let animationType = objc_getAssociatedObject(
            placeholder, &VModalFactory.animationTypeKey
        ) as? String ?? "none"
        panelPresenter(panel, animationType)
    }

    private func hideModal(for placeholder: NSView) {
        if let panel = objc_getAssociatedObject(placeholder, &VModalFactory.panelKey) as? NSWindow {
            if let floatingPanel = panel as? NSPanel {
                let animationType = objc_getAssociatedObject(
                    placeholder, &VModalFactory.animationTypeKey
                ) as? String ?? "none"
                objc_setAssociatedObject(
                    placeholder, &VModalFactory.panelKey,
                    nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                panelDismissal(floatingPanel, animationType)
                floatingPanel.delegate = nil
                objc_setAssociatedObject(
                    placeholder, &VModalFactory.panelDelegateKey,
                    nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )

                if let overlay = objc_getAssociatedObject(
                    placeholder, &VModalFactory.overlayKey
                ) as? FlippedView {
                    ExternalLayoutRootRegistry.unregister(overlay)
                    overlay.removeFromSuperview()
                }
                fireEvent(for: placeholder, key: &VModalFactory.onDismissKey)
                return
            }

            sheetDismissal(panel)
            if let overlay = objc_getAssociatedObject(
                placeholder, &VModalFactory.overlayKey
            ) as? FlippedView {
                ExternalLayoutRootRegistry.unregister(overlay)
                overlay.removeFromSuperview()
            }
        }
    }

    private func installCloseDelegate(on panel: NSPanel, for placeholder: NSView) {
        let closeDelegate = ModalPanelCloseDelegate { [weak self, weak placeholder, weak panel] in
            guard let self,
                  let placeholder,
                  let panel,
                  let activePanel = objc_getAssociatedObject(
                    placeholder, &VModalFactory.panelKey
                  ) as? NSPanel,
                  activePanel === panel else { return }

            objc_setAssociatedObject(
                placeholder, &VModalFactory.panelKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            objc_setAssociatedObject(
                placeholder, &VModalFactory.visibleKey,
                false, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            if let overlay = objc_getAssociatedObject(
                placeholder, &VModalFactory.overlayKey
            ) as? NSView {
                ExternalLayoutRootRegistry.unregister(overlay)
                overlay.removeFromSuperview()
            }
            panel.contentView = nil
            panel.delegate = nil
            objc_setAssociatedObject(
                placeholder, &VModalFactory.panelDelegateKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            self.fireEvent(for: placeholder, key: &VModalFactory.onDismissKey)
        }
        panel.delegate = closeDelegate
        objc_setAssociatedObject(
            placeholder, &VModalFactory.panelDelegateKey,
            closeDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private func fireEvent(for view: NSView, key: inout UInt8) {
        if let handler = objc_getAssociatedObject(view, &key) as? ((Any?) -> Void) {
            handler(nil)
        }
    }

}
