import AppKit
import ObjectiveC

/// Factory for VSafeArea — pass-through container on macOS.
/// macOS has no notches or system bars that require safe area insets,
/// so this component acts as a plain FlippedView container with gesture support.
final class VSafeAreaFactory: NativeComponentFactory {

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
        switch event {
        case "press":
            let wrapper = ClickGestureWrapper(handler: handler)
            let click = NSClickGestureRecognizer(
                target: wrapper,
                action: #selector(ClickGestureWrapper.handleGesture(_:))
            )
            view.addGestureRecognizer(click)
            GestureStorage.store(wrapper, for: view, event: event)

        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        GestureStorage.remove(for: view, event: event)
        if event == "press" {
            view.gestureRecognizers.forEach { recognizer in
                if let click = recognizer as? NSClickGestureRecognizer, click.buttonMask == 0x1 {
                    view.removeGestureRecognizer(recognizer)
                }
            }
        }
    }
}
