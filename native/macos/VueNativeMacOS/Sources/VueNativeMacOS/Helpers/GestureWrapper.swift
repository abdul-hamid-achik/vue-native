import AppKit

/// ObjC-compatible wrapper for gesture recognizer action handlers.
/// Allows attaching Swift closure-based event handlers to NSGestureRecognizers
/// that require an @objc selector target.
@objc final class ClickGestureWrapper: NSObject {

    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handleGesture(_ gesture: NSGestureRecognizer) {
        handler(nil)
    }

    @objc func handleGestureWithState(_ gesture: NSGestureRecognizer) {
        guard let view = gesture.view else {
            handler(nil)
            return
        }
        let location = gesture.location(in: view)
        let payload: [String: Any] = [
            "locationX": location.x,
            "locationY": location.y
        ]
        handler(payload)
    }
}

// MARK: - PanGestureWrapper

/// ObjC-compatible wrapper for NSPanGestureRecognizer action handlers.
@objc final class PanGestureWrapper: NSObject {
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handle(_ recognizer: NSPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let translation = recognizer.translation(in: view.superview)
        let velocity = recognizer.velocity(in: view.superview)
        let stateStr: String
        switch recognizer.state {
        case .began:             stateStr = "began"
        case .changed:           stateStr = "changed"
        case .ended:             stateStr = "ended"
        case .cancelled, .failed: stateStr = "cancelled"
        default:                 stateStr = "unknown"
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

// MARK: - MagnificationGestureWrapper

/// ObjC-compatible wrapper for NSMagnificationGestureRecognizer action handlers.
/// macOS equivalent of iOS PinchWrapper.
@objc final class MagnificationGestureWrapper: NSObject {
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handle(_ recognizer: NSMagnificationGestureRecognizer) {
        let stateStr: String
        switch recognizer.state {
        case .began:    stateStr = "began"
        case .changed:  stateStr = "changed"
        case .ended:    stateStr = "ended"
        default:        stateStr = "cancelled"
        }
        // Magnification is relative (0 = no change), convert to scale (1 = no change)
        // to match iOS pinch gesture API
        handler([
            "scale": 1.0 + recognizer.magnification,
            "state": stateStr
        ] as [String: Any])
    }
}
