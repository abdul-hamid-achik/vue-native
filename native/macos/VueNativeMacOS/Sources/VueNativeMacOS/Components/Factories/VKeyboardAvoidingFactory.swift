import AppKit

/// Factory for VKeyboardAvoiding — pass-through container on macOS.
/// macOS keyboards do not cover content (unlike iOS on-screen keyboards),
/// so this component acts as a plain FlippedView container for API compatibility.
final class VKeyboardAvoidingFactory: NativeComponentFactory {

    func createView() -> NSView {
        let view = FlippedView()
        view.ensureLayoutNode()
        return view
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        // Delegate all props to StyleEngine — acts as a plain container
        StyleEngine.apply(key: key, value: value, to: view)
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        // No-op — no keyboard avoidance on macOS
    }
}
