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
#endif
