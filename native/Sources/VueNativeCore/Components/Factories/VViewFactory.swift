#if canImport(UIKit)
import UIKit
import FlexLayout

/// Factory for VView — the basic container component.
/// Maps to a plain UIView with FlexLayout enabled.
/// Supports all style props via StyleEngine and optional tap gesture.
final class VViewFactory: NativeComponentFactory {

    func createView() -> UIView {
        let view = UIView()
        // Accessing view.flex automatically enables Yoga layout (FlexLayout's init sets yoga.isEnabled = true)
        _ = view.flex
        return view
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        // All VView props are style-related — delegate to StyleEngine
        StyleEngine.apply(key: key, value: value, to: view)
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        switch event {
        case "press":
            // Add tap gesture recognizer
            let wrapper = GestureWrapper(handler: handler)
            let tapRecognizer = UITapGestureRecognizer(
                target: wrapper,
                action: #selector(GestureWrapper.handleGesture(_:))
            )
            view.addGestureRecognizer(tapRecognizer)
            view.isUserInteractionEnabled = true

            // Store the wrapper to prevent deallocation
            GestureStorage.store(wrapper, for: view, event: event)

        case "longpress":
            let wrapper = GestureWrapper(handler: handler)
            let longPressRecognizer = UILongPressGestureRecognizer(
                target: wrapper,
                action: #selector(GestureWrapper.handleGestureWithState(_:))
            )
            longPressRecognizer.minimumPressDuration = 0.5
            view.addGestureRecognizer(longPressRecognizer)
            view.isUserInteractionEnabled = true

            GestureStorage.store(wrapper, for: view, event: event)

        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        GestureStorage.remove(for: view, event: event)
        // Remove matching gesture recognizers
        view.gestureRecognizers?.forEach { recognizer in
            if event == "press" && recognizer is UITapGestureRecognizer {
                view.removeGestureRecognizer(recognizer)
            } else if event == "longpress" && recognizer is UILongPressGestureRecognizer {
                view.removeGestureRecognizer(recognizer)
            }
        }
    }
}

// MARK: - GestureStorage

/// Stores GestureWrapper references as associated objects on views to prevent deallocation.
/// Uses a dictionary keyed by event name to support multiple gesture types per view.
enum GestureStorage {
    private static var storageKey: UInt8 = 0

    static func store(_ wrapper: GestureWrapper, for view: UIView, event: String) {
        var storage = getStorage(for: view)
        storage[event] = wrapper
        setStorage(storage, for: view)
    }

    static func remove(for view: UIView, event: String) {
        var storage = getStorage(for: view)
        storage.removeValue(forKey: event)
        setStorage(storage, for: view)
    }

    static func get(for view: UIView, event: String) -> GestureWrapper? {
        return getStorage(for: view)[event]
    }

    private static func getStorage(for view: UIView) -> [String: GestureWrapper] {
        return objc_getAssociatedObject(view, &storageKey) as? [String: GestureWrapper] ?? [:]
    }

    private static func setStorage(_ storage: [String: GestureWrapper], for view: UIView) {
        objc_setAssociatedObject(view, &storageKey, storage, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
#endif
