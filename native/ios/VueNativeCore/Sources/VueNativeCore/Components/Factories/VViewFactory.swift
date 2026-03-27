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

        // MARK: Rotation
        case "rotate":
            let rotationWrapper = RotationWrapper(handler: handler)
            let rotation = UIRotationGestureRecognizer(
                target: rotationWrapper,
                action: #selector(RotationWrapper.handle(_:))
            )
            view.addGestureRecognizer(rotation)
            view.isUserInteractionEnabled = true
            GestureStorage.storeObject(rotationWrapper, for: view, event: event)

        // MARK: Double Tap
        case "doubleTap":
            let wrapper = DoubleTapWrapper(handler: handler)
            let tapRecognizer = UITapGestureRecognizer(
                target: wrapper,
                action: #selector(DoubleTapWrapper.handleGesture(_:))
            )
            tapRecognizer.numberOfTapsRequired = 2
            view.addGestureRecognizer(tapRecognizer)
            view.isUserInteractionEnabled = true
            GestureStorage.storeObject(wrapper, for: view, event: event)

        // MARK: Force Touch (3D Touch)
        case "forceTouch":
            let wrapper = ForceTouchWrapper(handler: handler)
            // Force touch is handled via touch events, not gesture recognizers
            // We store the wrapper and will handle it in a custom touch handler
            GestureStorage.storeObject(wrapper, for: view, event: event)
            // Enable force touch on the view
            view.isUserInteractionEnabled = true
            attachForceTouchHandler(to: view, wrapper: wrapper)

        // MARK: Hover (iOS 13+)
        case "hover":
            if #available(iOS 13.0, *) {
                let hoverWrapper = HoverWrapper(handler: handler)
                let hover = UIHoverGestureRecognizer(
                    target: hoverWrapper,
                    action: #selector(HoverWrapper.handleGesture(_:))
                )
                view.addGestureRecognizer(hover)
                GestureStorage.storeObject(hoverWrapper, for: view, event: event)
            }

        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        GestureStorage.remove(for: view, event: event)
        // Remove matching gesture recognizers
        view.gestureRecognizers?.forEach { recognizer in
            switch event {
            case "press":
                if let tap = recognizer as? UITapGestureRecognizer, tap.numberOfTapsRequired == 1 {
                    view.removeGestureRecognizer(recognizer)
                }
            case "longpress"  where recognizer is UILongPressGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "pan"        where recognizer is UIPanGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "swipeLeft"   where recognizer is UISwipeGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "swipeRight"  where recognizer is UISwipeGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "swipeUp"     where recognizer is UISwipeGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "swipeDown"   where recognizer is UISwipeGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "pinch"      where recognizer is UIPinchGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "rotate"     where recognizer is UIRotationGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "doubleTap":
                if let tap = recognizer as? UITapGestureRecognizer, tap.numberOfTapsRequired == 2 {
                    view.removeGestureRecognizer(recognizer)
                }
            case "hover":
                if #available(iOS 13.0, *) {
                    if recognizer is UIHoverGestureRecognizer {
                        view.removeGestureRecognizer(recognizer)
                    }
                }
            default:
                break
            }
        }
    }

    // MARK: - Force Touch Helper

    private func attachForceTouchHandler(to view: UIView, wrapper: ForceTouchWrapper) {
        // ForceTouchHandler is attached via associated object
        let handler = ForceTouchHandlerView(wrapper: wrapper)
        objc_setAssociatedObject(view, &forceTouchHandlerKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        handler.attach(to: view)
    }
}

// MARK: - ForceTouchHandlerView

/// Custom UIView subclass that monitors force touch events
private class ForceTouchHandlerView: UIView {
    private let wrapper: ForceTouchWrapper
    private weak var targetView: UIView?

    init(wrapper: ForceTouchWrapper) {
        self.wrapper = wrapper
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attach(to view: UIView) {
        targetView = view
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let force = touch.force
        let location = touch.location(in: targetView)
        wrapper.handleTouch(force: force, location: location)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        let force = touch.force
        let location = touch.location(in: targetView)
        wrapper.handleTouch(force: force, location: location)
    }
}

private var forceTouchHandlerKey: UInt8 = 0

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
