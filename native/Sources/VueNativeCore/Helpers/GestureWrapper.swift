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
#endif
