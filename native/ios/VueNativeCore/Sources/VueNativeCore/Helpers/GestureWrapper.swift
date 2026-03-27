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

// MARK: - PanWrapper

/// ObjC-compatible wrapper for UIPanGestureRecognizer action handlers.
@objc final class PanWrapper: NSObject {
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handle(_ recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let translation = recognizer.translation(in: view.superview)
        let velocity = recognizer.velocity(in: view.superview)
        let stateStr: String
        switch recognizer.state {
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
