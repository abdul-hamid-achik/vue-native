#if canImport(UIKit)
import UIKit
import FlexLayout

/// Factory for VView — the basic container component.
/// Maps to a plain UIView with FlexLayout enabled.
/// Supports all style props via StyleEngine and gesture events.
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

        // MARK: Tap / Press
        case "press":
            let wrapper = GestureWrapper(handler: handler)
            let tapRecognizer = UITapGestureRecognizer(
                target: wrapper,
                action: #selector(GestureWrapper.handleGesture(_:))
            )
            view.addGestureRecognizer(tapRecognizer)
            view.isUserInteractionEnabled = true
            GestureStorage.store(wrapper, for: view, event: event)

        // MARK: Long Press
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

        // MARK: Pan
        case "pan":
            let panWrapper = PanWrapper(handler: handler)
            let pan = UIPanGestureRecognizer(
                target: panWrapper,
                action: #selector(PanWrapper.handle(_:))
            )
            view.addGestureRecognizer(pan)
            view.isUserInteractionEnabled = true
            GestureStorage.storeObject(panWrapper, for: view, event: event)

        // MARK: Swipe
        case "swipeLeft", "swipeRight", "swipeUp", "swipeDown":
            let direction: UISwipeGestureRecognizer.Direction
            let dirStr: String
            switch event {
            case "swipeLeft":  direction = .left;  dirStr = "left"
            case "swipeRight": direction = .right; dirStr = "right"
            case "swipeUp":    direction = .up;    dirStr = "up"
            default:           direction = .down;  dirStr = "down"
            }
            let swipeWrapper = SwipeWrapper(handler: handler, direction: dirStr)
            let swipe = UISwipeGestureRecognizer(
                target: swipeWrapper,
                action: #selector(SwipeWrapper.handle(_:))
            )
            swipe.direction = direction
            view.addGestureRecognizer(swipe)
            view.isUserInteractionEnabled = true
            GestureStorage.storeObject(swipeWrapper, for: view, event: event)

        // MARK: Pinch
        case "pinch":
            let pinchWrapper = PinchWrapper(handler: handler)
            let pinch = UIPinchGestureRecognizer(
                target: pinchWrapper,
                action: #selector(PinchWrapper.handle(_:))
            )
            view.addGestureRecognizer(pinch)
            view.isUserInteractionEnabled = true
            GestureStorage.storeObject(pinchWrapper, for: view, event: event)

        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        GestureStorage.remove(for: view, event: event)
        // Remove matching gesture recognizers
        view.gestureRecognizers?.forEach { recognizer in
            switch event {
            case "press"      where recognizer is UITapGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "longpress"  where recognizer is UILongPressGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "pan"        where recognizer is UIPanGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "swipeLeft", "swipeRight", "swipeUp", "swipeDown"
                              where recognizer is UISwipeGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "pinch"      where recognizer is UIPinchGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            default:
                break
            }
        }
    }
}

// MARK: - GestureStorage

/// Stores gesture wrapper references as associated objects on views to prevent deallocation.
/// Uses a dictionary keyed by event name to support multiple gesture types per view.
/// The values are stored as AnyObject (NSObject subclasses) so both GestureWrapper and
/// the newer PanWrapper / SwipeWrapper / PinchWrapper can be stored.
enum GestureStorage {
    private static var storageKey: UInt8 = 0

    // MARK: Legacy — typed store for GestureWrapper (keeps callers in VRootFactory compiling)
    static func store(_ wrapper: GestureWrapper, for view: UIView, event: String) {
        storeObject(wrapper, for: view, event: event)
    }

    // MARK: Generic store for any NSObject-derived wrapper
    static func storeObject(_ wrapper: NSObject, for view: UIView, event: String) {
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
        return getStorage(for: view)[event] as? GestureWrapper
    }

    private static func getStorage(for view: UIView) -> [String: NSObject] {
        return objc_getAssociatedObject(view, &storageKey) as? [String: NSObject] ?? [:]
    }

    private static func setStorage(_ storage: [String: NSObject], for view: UIView) {
        objc_setAssociatedObject(view, &storageKey, storage, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
#endif
