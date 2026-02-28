import AppKit

/// Factory for VStatusBar — no-op on macOS.
/// macOS does not have an app status bar like iOS. This factory exists
/// for API compatibility so that cross-platform code using VStatusBar
/// does not break on macOS.
final class VStatusBarFactory: NativeComponentFactory {

    func createView() -> NSView {
        let view = FlippedView()
        view.isHidden = true
        let node = view.ensureLayoutNode()
        node.width = .points(0)
        node.height = .points(0)
        return view
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        // No-op — macOS has no app status bar
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        // No-op
    }
}
