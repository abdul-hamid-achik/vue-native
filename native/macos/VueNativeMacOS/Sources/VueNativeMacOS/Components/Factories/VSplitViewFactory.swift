import AppKit
import ObjectiveC

/// Factory for VSplitView — macOS-specific split pane component.
/// Maps to NSSplitView for side-by-side or top-and-bottom pane arrangements.
///
/// Props:
///   - direction: "horizontal" | "vertical" (horizontal = side-by-side, vertical = top-bottom)
///   - dividerStyle: "thin" | "thick" | "paneSplitter"
///   - dividerColor: hex color string
///   - dividerPosition: CGFloat (position of the first divider in points)
///
/// Events:
///   - resize -> { positions: [CGFloat] }
final class VSplitViewFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var delegateKey: UInt8 = 0
    private static var resizeHandlerKey: UInt8 = 0
    nonisolated(unsafe) static var dividerColorKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let splitView = VNSplitView()
        splitView.isVertical = true  // side-by-side by default
        splitView.dividerStyle = .thin
        splitView.wantsLayer = true
        splitView.ensureLayoutNode()

        let delegate = SplitViewDelegate(factory: self, view: splitView)
        splitView.delegate = delegate
        objc_setAssociatedObject(
            splitView, &VSplitViewFactory.delegateKey,
            delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        return splitView
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let splitView = view as? NSSplitView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "direction":
            if let direction = value as? String {
                // "horizontal" means side-by-side (isVertical = true in NSSplitView terminology)
                // "vertical" means top-and-bottom (isVertical = false)
                splitView.isVertical = (direction == "horizontal")
            }

        case "dividerStyle":
            if let style = value as? String {
                switch style {
                case "thin":
                    splitView.dividerStyle = .thin
                case "thick":
                    splitView.dividerStyle = .thick
                case "paneSplitter":
                    splitView.dividerStyle = .paneSplitter
                default:
                    splitView.dividerStyle = .thin
                }
            }

        case "dividerColor":
            if let hex = value as? String {
                let color = NSColor.fromHex(hex)
                objc_setAssociatedObject(
                    view, &VSplitViewFactory.dividerColorKey,
                    color, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                splitView.needsDisplay = true
            }

        case "dividerPosition":
            let position: CGFloat
            if let p = value as? Double {
                position = CGFloat(p)
            } else if let p = value as? Int {
                position = CGFloat(p)
            } else {
                return
            }
            if splitView.arrangedSubviews.count >= 2 {
                splitView.setPosition(position, ofDividerAt: 0)
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        switch event {
        case "resize":
            objc_setAssociatedObject(
                view, &VSplitViewFactory.resizeHandlerKey,
                handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        switch event {
        case "resize":
            objc_setAssociatedObject(
                view, &VSplitViewFactory.resizeHandlerKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    // MARK: - Child management

    func insertChild(_ child: NSView, into parent: NSView, before anchor: NSView?) {
        guard let splitView = parent as? NSSplitView else {
            if let anchor = anchor, parent.subviews.contains(anchor) {
                parent.addSubview(child, positioned: .below, relativeTo: anchor)
            } else {
                parent.addSubview(child)
            }
            child.ensureLayoutNode()
            return
        }

        if let anchor = anchor, let idx = splitView.arrangedSubviews.firstIndex(of: anchor) {
            splitView.insertArrangedSubview(child, at: idx)
        } else {
            splitView.addArrangedSubview(child)
        }
        child.ensureLayoutNode()
    }

    func removeChild(_ child: NSView, from parent: NSView) {
        guard let splitView = parent as? NSSplitView else {
            child.removeFromSuperview()
            return
        }
        splitView.removeArrangedSubview(child)
        child.removeFromSuperview()
    }

    // MARK: - Internal resize notification

    fileprivate func notifyResize(view: NSSplitView) {
        guard let handler = objc_getAssociatedObject(
            view, &VSplitViewFactory.resizeHandlerKey
        ) as? (Any?) -> Void else { return }

        var positions: [CGFloat] = []
        let count = max(0, view.arrangedSubviews.count - 1)
        for i in 0..<count {
            if view.isVertical {
                var pos: CGFloat = 0
                for j in 0...i {
                    pos += view.arrangedSubviews[j].frame.width
                    if j < i { pos += view.dividerThickness }
                }
                positions.append(pos)
            } else {
                var pos: CGFloat = 0
                for j in 0...i {
                    pos += view.arrangedSubviews[j].frame.height
                    if j < i { pos += view.dividerThickness }
                }
                positions.append(pos)
            }
        }

        handler(["positions": positions])
    }
}

// MARK: - VNSplitView (custom divider color support)

private class VNSplitView: NSSplitView {
    override var dividerColor: NSColor {
        if let custom = objc_getAssociatedObject(
            self, &VSplitViewFactory.dividerColorKey
        ) as? NSColor {
            return custom
        }
        return super.dividerColor
    }
}

// MARK: - SplitViewDelegate

private final class SplitViewDelegate: NSObject, NSSplitViewDelegate {

    private weak var factory: VSplitViewFactory?
    private weak var view: NSSplitView?

    init(factory: VSplitViewFactory, view: NSSplitView) {
        self.factory = factory
        self.view = view
        super.init()
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard let view = view, let factory = factory else { return }
        factory.notifyResize(view: view)
    }
}
