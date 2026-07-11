import AppKit

@MainActor
enum ExternalLayoutRootRegistry {
    private final class WeakView {
        weak var value: NSView?

        init(_ value: NSView) {
            self.value = value
        }
    }

    private static var roots: [ObjectIdentifier: WeakView] = [:]

    static func register(_ view: NSView) {
        roots[ObjectIdentifier(view)] = WeakView(view)
    }

    static func unregister(_ view: NSView) {
        roots.removeValue(forKey: ObjectIdentifier(view))
    }

    static func layoutAll() {
        var staleIdentifiers: [ObjectIdentifier] = []
        for (identifier, weakView) in roots {
            guard let view = weakView.value else {
                staleIdentifiers.append(identifier)
                continue
            }
            view.layoutSubtreeIfNeeded()
            guard view.bounds.width > 0, view.bounds.height > 0 else { continue }
            view.layoutNode?.layout(
                availableWidth: view.bounds.width,
                availableHeight: view.bounds.height
            )
        }
        for identifier in staleIdentifiers {
            roots.removeValue(forKey: identifier)
        }
    }
}

final class ModalContentView: FlippedView {
    override func layout() {
        super.layout()
        layoutManagedContent()
    }

    func layoutManagedContent() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        layoutNode?.layout(
            availableWidth: bounds.width,
            availableHeight: bounds.height
        )
    }
}

final class ModalPanelCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

@MainActor
enum VModalPresentation {
    static func presentSheet(
        _ sheet: NSWindow,
        completion: @escaping VModalFactory.SheetCompletion
    ) -> Bool {
        guard let parentWindow = NSApplication.shared.keyWindow else { return false }
        parentWindow.beginSheet(sheet, completionHandler: completion)
        return true
    }

    static func dismissSheet(_ sheet: NSWindow) {
        guard let parentWindow = sheet.sheetParent else { return }
        parentWindow.endSheet(sheet)
    }

    static func presentPanel(_ panel: NSPanel, animationType: String) {
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

    static func dismissPanel(_ panel: NSPanel, animationType: String) {
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
}
