import AppKit

/// Factory for VRefreshControl — stub on macOS.
/// Pull-to-refresh is a mobile pattern that does not exist on desktop.
/// This factory exists for API compatibility so that cross-platform code
/// using VRefreshControl does not break on macOS.
final class VRefreshControlFactory: NativeComponentFactory {

    func createView() -> NSView {
        let view = FlippedView()
        view.isHidden = true
        let node = view.ensureLayoutNode()
        node.width = .points(0)
        node.height = .points(0)
        return view
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        // No-op — pull-to-refresh doesn't exist on macOS
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        // No-op
    }
}
