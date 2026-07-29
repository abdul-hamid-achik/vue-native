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
///
/// When the view marks `pan` as native-driven (via the `nativeDrivenGestures` prop),
/// this wrapper also applies the pan translation directly to the view's layer transform
/// on the UI thread, so dragging stays smooth without a JS round-trip per frame. The
/// `pan` event is still delivered to JS in both modes.
@objc final class PanGestureWrapper: NSObject {
    private let handler: (Any?) -> Void

    /// The layer transform captured at `.began`, used as the base the pan translation
    /// is composed onto. This preserves any style-driven transform (StyleEngine writes
    /// `transform` straight to `layer.transform`) instead of clobbering it.
    private var baseTransform: CATransform3D = CATransform3DIdentity

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handle(_ recognizer: NSPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let translation = recognizer.translation(in: view.superview)
        let velocity = recognizer.velocity(in: view.superview)
        process(view: view, translation: translation, velocity: velocity, state: recognizer.state)
    }

    /// Core pan handling. Exposed (instead of only the `@objc` recognizer entry point)
    /// so the transform logic can be driven deterministically in tests without a live
    /// recognizer event stream.
    ///
    /// Gesture-recognizer actions are delivered on the main thread, so mutating the
    /// layer here satisfies the "UI on main" rule.
    func process(view: NSView, translation: CGPoint, velocity: CGPoint, state: NSGestureRecognizer.State) {
        if NativeDrivenGestureStorage.isNativeDriven("pan", for: view) {
            applyNativeDrivenTranslation(to: view, translation: translation, state: state)
        }

        let stateStr: String
        switch state {
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

    /// Apply the pan translation directly to the view's layer transform.
    ///
    /// - At `.began` the current layer transform is captured as the base (this is the
    ///   style transform, if any).
    /// - At `.changed`/`.ended` the translation is composed *on top of* that base via
    ///   `CATransform3DConcat(base, translation)`, so the style transform is preserved
    ///   and the translation is expressed in the view's superview coordinate space.
    /// - `.ended` leaves the last applied transform in place (no reset).
    ///
    /// Interaction with StyleEngine: if a `transform` style prop is (re)applied while a
    /// native-driven pan is in flight it overwrites `layer.transform`; the next `.changed`
    /// recomposes from the base captured at the gesture's `.began`. Style transforms and
    /// native-driven pans on the same view are therefore best treated as mutually exclusive.
    private func applyNativeDrivenTranslation(to view: NSView, translation: CGPoint, state: NSGestureRecognizer.State) {
        guard let layer = view.layer else { return }
        switch state {
        case .began:
            baseTransform = layer.transform
        case .changed, .ended:
            let translate = CATransform3DMakeTranslation(translation.x, translation.y, 0)
            layer.transform = CATransform3DConcat(baseTransform, translate)
        default:
            break
        }
    }
}

// MARK: - MagnificationGestureWrapper

/// ObjC-compatible wrapper for NSMagnificationGestureRecognizer action handlers.
/// macOS equivalent of iOS PinchWrapper.
///
/// When the view marks `pinch` as native-driven (via the `nativeDrivenGestures`
/// prop), this wrapper also applies the magnification directly to the view's layer
/// transform on the UI thread, so scaling stays smooth without a JS round-trip per
/// frame. The `pinch` event is still delivered to JS in both modes.
@objc final class MagnificationGestureWrapper: NSObject {
    private let handler: (Any?) -> Void

    /// The layer transform captured at `.began`, used as the base the pinch scale is
    /// composed onto. This preserves any style-driven transform (StyleEngine writes
    /// `transform` straight to `layer.transform`) instead of clobbering it.
    private var baseTransform: CATransform3D = CATransform3DIdentity

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handle(_ recognizer: NSMagnificationGestureRecognizer) {
        guard let view = recognizer.view else { return }
        process(view: view, magnification: recognizer.magnification, state: recognizer.state)
    }

    /// Core magnification handling. Exposed (instead of only the `@objc` recognizer
    /// entry point) so the transform logic can be driven deterministically in tests
    /// without a live recognizer event stream.
    ///
    /// Gesture-recognizer actions are delivered on the main thread, so mutating the
    /// layer here satisfies the "UI on main" rule.
    func process(view: NSView, magnification: CGFloat, state: NSGestureRecognizer.State) {
        if NativeDrivenGestureStorage.isNativeDriven("pinch", for: view) {
            applyNativeDrivenScale(to: view, magnification: magnification, state: state)
        }

        let stateStr: String
        switch state {
        case .began:    stateStr = "began"
        case .changed:  stateStr = "changed"
        case .ended:    stateStr = "ended"
        default:        stateStr = "cancelled"
        }
        // Magnification is relative (0 = no change), convert to scale (1 = no change)
        // to match iOS pinch gesture API
        handler([
            "scale": 1.0 + magnification,
            "state": stateStr
        ] as [String: Any])
    }

    /// Apply the pinch magnification directly to the view's layer transform.
    ///
    /// - At `.began` the current layer transform is captured as the base (this is the
    ///   style transform, if any).
    /// - At `.changed`/`.ended` the scale (`1 + magnification`) is composed *on top of*
    ///   that base via `CATransform3DScale(base, s, s, 1)`, so the style transform is
    ///   preserved. `magnification` is cumulative since the gesture began (0 at start),
    ///   matching the scale delivered to JS.
    /// - `.ended` leaves the last applied transform in place (no reset).
    ///
    /// Interaction with StyleEngine / other native-driven gestures mirrors the pan
    /// wrapper: a `transform` style prop (or another native-driven gesture) applied
    /// mid-flight overwrites `layer.transform`; treat style transforms and native-driven
    /// gestures on the same view as mutually exclusive.
    private func applyNativeDrivenScale(to view: NSView, magnification: CGFloat, state: NSGestureRecognizer.State) {
        guard let layer = view.layer else { return }
        switch state {
        case .began:
            baseTransform = layer.transform
        case .changed, .ended:
            let scale = 1.0 + magnification
            layer.transform = CATransform3DScale(baseTransform, scale, scale, 1)
        default:
            break
        }
    }
}

// MARK: - RotationGestureWrapper

/// ObjC-compatible wrapper for NSRotationGestureRecognizer action handlers.
///
/// When the view marks `rotate` as native-driven (via the `nativeDrivenGestures`
/// prop), this wrapper also applies the rotation directly to the view's layer
/// transform on the UI thread, so rotating stays smooth without a JS round-trip per
/// frame. The `rotate` event is still delivered to JS in both modes.
@objc final class RotationGestureWrapper: NSObject {
    private let handler: (Any?) -> Void

    /// The layer transform captured at `.began`, used as the base the rotation is
    /// composed onto. This preserves any style-driven transform (StyleEngine writes
    /// `transform` straight to `layer.transform`) instead of clobbering it.
    private var baseTransform: CATransform3D = CATransform3DIdentity

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handle(_ recognizer: NSRotationGestureRecognizer) {
        guard let view = recognizer.view else { return }
        process(view: view, rotation: recognizer.rotation, state: recognizer.state)
    }

    /// Core rotation handling. Exposed (instead of only the `@objc` recognizer entry
    /// point) so the transform logic can be driven deterministically in tests without a
    /// live recognizer event stream.
    ///
    /// Gesture-recognizer actions are delivered on the main thread, so mutating the
    /// layer here satisfies the "UI on main" rule.
    func process(view: NSView, rotation: CGFloat, state: NSGestureRecognizer.State) {
        if NativeDrivenGestureStorage.isNativeDriven("rotate", for: view) {
            applyNativeDrivenRotation(to: view, rotation: rotation, state: state)
        }

        let stateStr: String
        switch state {
        case .began:    stateStr = "began"
        case .changed:  stateStr = "changed"
        case .ended:    stateStr = "ended"
        default:        stateStr = "cancelled"
        }
        handler([
            "rotation": rotation,
            "state": stateStr
        ] as [String: Any])
    }

    /// Apply the rotation directly to the view's layer transform.
    ///
    /// - At `.began` the current layer transform is captured as the base (this is the
    ///   style transform, if any).
    /// - At `.changed`/`.ended` the rotation (radians, cumulative since the gesture
    ///   began, 0 at start) is composed *on top of* that base via
    ///   `CATransform3DRotate(base, rotation, 0, 0, 1)` (about the Z axis), so the style
    ///   transform is preserved.
    /// - `.ended` leaves the last applied transform in place (no reset).
    ///
    /// Interaction with StyleEngine / other native-driven gestures mirrors the pan
    /// wrapper: treat style transforms and native-driven gestures on the same view as
    /// mutually exclusive.
    private func applyNativeDrivenRotation(to view: NSView, rotation: CGFloat, state: NSGestureRecognizer.State) {
        guard let layer = view.layer else { return }
        switch state {
        case .began:
            baseTransform = layer.transform
        case .changed, .ended:
            layer.transform = CATransform3DRotate(baseTransform, rotation, 0, 0, 1)
        default:
            break
        }
    }
}

// MARK: - DoubleClickWrapper

/// ObjC-compatible wrapper for double-click gesture handlers.
@objc final class DoubleClickWrapper: NSObject {
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handleGesture(_ gesture: NSClickGestureRecognizer) {
        let location = gesture.location(in: gesture.view)
        let payload: [String: Any] = [
            "locationX": location.x,
            "locationY": location.y
        ]
        handler(payload)
    }
}

// MARK: - HoverWrapper

/// Wrapper for hover gesture handlers (tracking area based).
@objc final class HoverWrapper: NSObject {
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    func handleHover(location: NSPoint, isEntering: Bool) {
        let payload: [String: Any] = [
            "locationX": location.x,
            "locationY": location.y,
            "state": isEntering ? "entered" : "exited"
        ]
        handler(payload)
    }
}

// MARK: - PressureWrapper

/// Wrapper for pressure/force gesture handlers (Force Touch on macOS).
@objc final class PressureWrapper: NSObject {
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    func handlePressure(pressure: CGFloat, location: NSPoint, stage: Int) {
        let payload: [String: Any] = [
            "force": pressure,
            "locationX": location.x,
            "locationY": location.y,
            "stage": stage
        ]
        handler(payload)
    }
}
