import AppKit
import ObjectiveC

/// Factory for VModal — presents content in a modal panel or sheet.
/// The view itself is a zero-size hidden placeholder in the native tree.
/// Its children are moved into an NSPanel when visible=true.
final class VModalFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var panelKey: UInt8 = 0
    private static var visibleKey: UInt8 = 1
    private static var animationTypeKey: UInt8 = 2
    private static var transparentKey: UInt8 = 3
    private static var presentationStyleKey: UInt8 = 4
    private static var onDismissKey: UInt8 = 5
    private static var onShowKey: UInt8 = 6
    private static var overlayKey: UInt8 = 7

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
            let visible = (value as? Bool) ?? ((value as? Int) != nil && (value as! Int) != 0)
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
            break
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

    // Custom child management: route children to the overlay container
    func insertChild(_ child: NSView, into parent: NSView, before anchor: NSView?) {
        let overlay = getOrCreateOverlay(for: parent)
        if let anchor = anchor, let idx = overlay.subviews.firstIndex(of: anchor) {
            overlay.addSubview(child, positioned: .below, relativeTo: anchor)
        } else {
            overlay.addSubview(child)
        }
        child.ensureLayoutNode()
    }

    func removeChild(_ child: NSView, from parent: NSView) {
        child.removeFromSuperview()
    }

    // MARK: - Private helpers

    private func getOrCreateOverlay(for placeholder: NSView) -> FlippedView {
        if let existing = objc_getAssociatedObject(placeholder, &VModalFactory.overlayKey) as? FlippedView {
            return existing
        }
        let overlay = FlippedView()
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
        let transparent = objc_getAssociatedObject(placeholder, &VModalFactory.transparentKey) as? Bool ?? false
        let animationType = objc_getAssociatedObject(placeholder, &VModalFactory.animationTypeKey) as? String ?? "none"

        let overlay = getOrCreateOverlay(for: placeholder)

        if style == "sheet" {
            // Present as sheet on the key window
            guard let parentWindow = NSApplication.shared.keyWindow else { return }

            let sheetWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            sheetWindow.contentView = overlay
            objc_setAssociatedObject(
                placeholder, &VModalFactory.panelKey,
                sheetWindow, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

            parentWindow.beginSheet(sheetWindow) { [weak placeholder] _ in
                guard let placeholder = placeholder else { return }
                self.fireEvent(for: placeholder, key: &VModalFactory.onDismissKey)
            }
        } else {
            // Present as floating panel
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .resizable, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true

            if transparent {
                panel.isOpaque = false
                panel.backgroundColor = .clear
            } else {
                panel.backgroundColor = NSColor(white: 0.95, alpha: 1.0)
            }

            panel.contentView = overlay
            objc_setAssociatedObject(
                placeholder, &VModalFactory.panelKey,
                panel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

            if animationType == "fade" {
                panel.alphaValue = 0
                panel.makeKeyAndOrderFront(nil)
                panel.center()
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    panel.animator().alphaValue = 1
                }
            } else {
                panel.makeKeyAndOrderFront(nil)
                panel.center()
            }
        }

        fireEvent(for: placeholder, key: &VModalFactory.onShowKey)
    }

    private func hideModal(for placeholder: NSView) {
        if let panel = objc_getAssociatedObject(placeholder, &VModalFactory.panelKey) as? NSWindow {
            if let parentWindow = panel.sheetParent {
                parentWindow.endSheet(panel)
            } else {
                let animationType = objc_getAssociatedObject(placeholder, &VModalFactory.animationTypeKey) as? String ?? "none"
                if animationType == "fade" {
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.25
                        panel.animator().alphaValue = 0
                    }, completionHandler: {
                        panel.orderOut(nil)
                    })
                } else {
                    panel.orderOut(nil)
                }
            }

            // Move overlay back to placeholder ownership (detach from panel)
            if let overlay = objc_getAssociatedObject(placeholder, &VModalFactory.overlayKey) as? FlippedView {
                overlay.removeFromSuperview()
            }

            fireEvent(for: placeholder, key: &VModalFactory.onDismissKey)
        }
    }

    private func fireEvent(for view: NSView, key: inout UInt8) {
        if let handler = objc_getAssociatedObject(view, &key) as? ((Any?) -> Void) {
            handler(nil)
        }
    }
}
