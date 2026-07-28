#if canImport(UIKit)
import UIKit

/// ObjC-compatible wrapper for gesture recognizer action handlers.
/// Allows attaching Swift closure-based event handlers to UIGestureRecognizers
/// that require an @objc selector target.
@objc final class GestureWrapper: NSObject {

    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handleGesture(_ gesture: UIGestureRecognizer) {
        handler(nil)
    }

    @objc func handleGestureWithState(_ gesture: UIGestureRecognizer) {
        let payload: [String: Any] = [
            "state": gesture.state.rawValue,
            "locationX": gesture.location(in: gesture.view).x,
            "locationY": gesture.location(in: gesture.view).y
        ]
        handler(payload)
    }
}

// MARK: - NativeDrivenGestures

/// Stores which gestures are "native-driven" on a view, keyed as an associated object.
///
/// The JS runtime sets the `nativeDrivenGestures` prop (an array of gesture names,
/// e.g. `["pan"]`) via `updateProp`. When a gesture name is present here, the native
/// gesture handler drives the visual change directly on the UI thread (e.g. a pan
/// applies its translation to the view transform) instead of waiting for a JS
/// round-trip per frame. The gesture event is still forwarded to JS in both modes.
///
/// Stored on the view (rather than on the gesture wrapper) so the prop and the
/// gesture listener can arrive in any order — the wrapper reads the flag live at
/// gesture time.
enum NativeDrivenGestures {
    private static var storageKey: UInt8 = 0

    /// Replace the set of native-driven gesture names on a view.
    static func set(_ gestures: [String], for view: UIView) {
        objc_setAssociatedObject(view, &storageKey, gestures, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Whether the given gesture name is marked native-driven on the view.
    static func contains(_ gesture: String, in view: UIView) -> Bool {
        let gestures = objc_getAssociatedObject(view, &storageKey) as? [String] ?? []
        return gestures.contains(gesture)
    }
}

// MARK: - PanWrapper

/// ObjC-compatible wrapper for UIPanGestureRecognizer action handlers.
///
/// When `"pan"` is marked native-driven on the view (see ``NativeDrivenGestures``),
/// the wrapper applies the pan translation directly to `view.transform` on the UI
/// thread on every `.changed`, removing the JS round-trip per frame. The translation
/// is accumulated on top of the transform that was present when the drag began, so a
/// style-applied 2D transform (scale/rotate) is preserved. Note this operates on the
/// affine `view.transform`; a 3D `layer.transform` set by style is flattened to its
/// 2D projection while a native-driven drag is active. The `pan` event is forwarded
/// to JS in all cases so state tracking and `ended` handling keep working.
@objc final class PanWrapper: NSObject {
    private let handler: (Any?) -> Void

    /// Transform present when the current native-driven drag began, so the drag
    /// translation is accumulated on top of any style-applied transform.
    private var baseTransform: CGAffineTransform = .identity

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handle(_ recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let translation = recognizer.translation(in: view.superview)
        let velocity = recognizer.velocity(in: view.superview)
        handlePan(view: view, state: recognizer.state, translation: translation, velocity: velocity)
    }

    /// Core pan handling, factored out of the recognizer callback so it can be
    /// exercised in unit tests without synthesizing touches. Applies the
    /// native-driven transform when enabled, then always forwards the event to JS.
    func handlePan(view: UIView, state: UIGestureRecognizer.State, translation: CGPoint, velocity: CGPoint) {
        if NativeDrivenGestures.contains("pan", in: view) {
            switch state {
            case .began:
                baseTransform = view.transform
            case .changed:
                // Translate in superview space on top of the captured base transform.
                view.transform = baseTransform.concatenating(
                    CGAffineTransform(translationX: translation.x, y: translation.y)
                )
            default:
                // ended/cancelled/failed: leave the view at its last dragged position;
                // JS may adjust it further via the `transform` style if it wants.
                break
            }
        }

        let stateStr: String
        switch state {
        case .began:            stateStr = "began"
        case .changed:          stateStr = "changed"
        case .ended:            stateStr = "ended"
        case .cancelled, .failed: stateStr = "cancelled"
        default:                stateStr = "unknown"
        }
        handler([
            "translationX": translation.x,
            "translationY": translation.y,
            "velocityX": velocity.x,
            "velocityY": velocity.y,
            "state": stateStr
        ] as [String: Any])
    }
}

// MARK: - SwipeWrapper

/// ObjC-compatible wrapper for UISwipeGestureRecognizer action handlers.
@objc final class SwipeWrapper: NSObject {
    private let handler: (Any?) -> Void
    private let direction: String

    init(handler: @escaping (Any?) -> Void, direction: String) {
        self.handler = handler
        self.direction = direction
        super.init()
    }

    @objc func handle(_ recognizer: UISwipeGestureRecognizer) {
        handler(["direction": direction] as [String: Any])
    }
}

// MARK: - PinchWrapper

/// ObjC-compatible wrapper for UIPinchGestureRecognizer action handlers.
@objc final class PinchWrapper: NSObject {
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handle(_ recognizer: UIPinchGestureRecognizer) {
        let stateStr: String
        switch recognizer.state {
        case .began:    stateStr = "began"
        case .changed:  stateStr = "changed"
        case .ended:    stateStr = "ended"
        default:        stateStr = "cancelled"
        }
        handler([
            "scale": recognizer.scale,
            "velocity": recognizer.velocity,
            "state": stateStr
        ] as [String: Any])
    }
}

// MARK: - RotationWrapper

/// ObjC-compatible wrapper for UIRotationGestureRecognizer action handlers.
@objc final class RotationWrapper: NSObject {
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handle(_ recognizer: UIRotationGestureRecognizer) {
        let stateStr: String
        switch recognizer.state {
        case .began:    stateStr = "began"
        case .changed:  stateStr = "changed"
        case .ended:    stateStr = "ended"
        default:        stateStr = "cancelled"
        }
        handler([
            "rotation": recognizer.rotation,
            "velocity": recognizer.velocity,
            "state": stateStr
        ] as [String: Any])
    }
}

// MARK: - ForceTouchWrapper

/// Wrapper for 3D Touch / Force Touch gesture handlers.
@objc final class ForceTouchWrapper: NSObject {
    private let handler: (Any?) -> Void
    private var lastForce: CGFloat = 0

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    func handleTouch(force: CGFloat, location: CGPoint) {
        let payload: [String: Any] = [
            "force": force,
            "locationX": location.x,
            "locationY": location.y
        ]
        handler(payload)
    }
}

// MARK: - DoubleTapWrapper

/// ObjC-compatible wrapper for double-tap gesture handlers.
@objc final class DoubleTapWrapper: NSObject {
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handleGesture(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: gesture.view)
        let payload: [String: Any] = [
            "locationX": location.x,
            "locationY": location.y
        ]
        handler(payload)
    }
}

// MARK: - HoverWrapper

/// Wrapper for hover gesture handlers (iOS 13+).
@objc final class HoverWrapper: NSObject {
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handleGesture(_ gesture: UIHoverGestureRecognizer) {
        guard let view = gesture.view else { return }
        let location = gesture.location(in: view)
        let stateStr: String
        switch gesture.state {
        case .began:    stateStr = "began"
        case .changed:  stateStr = "changed"
        case .ended:    stateStr = "ended"
        default:        stateStr = "cancelled"
        }
        let payload: [String: Any] = [
            "locationX": location.x,
            "locationY": location.y,
            "state": stateStr
        ]
        handler(payload)
    }
}
#endif
