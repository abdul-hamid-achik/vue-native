#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Tests for native-driven pinch and rotate gestures.
///
/// When a view's `nativeDrivenGestures` prop contains `"pinch"`/`"rotate"`, the
/// corresponding handler must apply the scale/rotation directly to the view transform
/// on the UI thread (no JS round-trip per frame) while still forwarding the gesture
/// event to JS. Without the prop, the transform must be left untouched (the
/// pre-existing JS-driven behavior).
///
/// The gesture lifecycles are driven through
/// ``PinchWrapper/handlePinch(view:state:scale:velocity:)`` and
/// ``RotationWrapper/handleRotation(view:state:rotation:velocity:)`` — the same code
/// paths the recognizer callbacks use — because `UIPinchGestureRecognizer` /
/// `UIRotationGestureRecognizer` values cannot be synthesized in a unit test without a
/// UI-test target.
@MainActor
final class NativeDrivenPinchRotateGestureTests: XCTestCase {

    // MARK: - Helpers

    /// Build a VView, wire a `pinch` listener through the factory, and return the view
    /// plus the factory-installed ``PinchWrapper`` so tests can drive the real wiring.
    private func makePinchView(
        nativeDriven: Bool,
        onEvent: @escaping ([String: Any]) -> Void
    ) -> (view: UIView, wrapper: PinchWrapper) {
        let factory = VViewFactory()
        let view = factory.createView()
        if nativeDriven {
            factory.updateProp(view: view, key: "nativeDrivenGestures", value: ["pinch"])
        }
        factory.addEventListener(view: view, event: "pinch") { payload in
            if let dict = payload as? [String: Any] {
                onEvent(dict)
            }
        }
        guard let wrapper = GestureStorage.getObject(for: view, event: "pinch") as? PinchWrapper else {
            XCTFail("VViewFactory did not store a PinchWrapper for the pinch event")
            fatalError("unreachable")
        }
        return (view, wrapper)
    }

    /// Build a VView, wire a `rotate` listener through the factory, and return the view
    /// plus the factory-installed ``RotationWrapper`` so tests can drive the real wiring.
    private func makeRotateView(
        nativeDriven: Bool,
        onEvent: @escaping ([String: Any]) -> Void
    ) -> (view: UIView, wrapper: RotationWrapper) {
        let factory = VViewFactory()
        let view = factory.createView()
        if nativeDriven {
            factory.updateProp(view: view, key: "nativeDrivenGestures", value: ["rotate"])
        }
        factory.addEventListener(view: view, event: "rotate") { payload in
            if let dict = payload as? [String: Any] {
                onEvent(dict)
            }
        }
        guard let wrapper = GestureStorage.getObject(for: view, event: "rotate") as? RotationWrapper else {
            XCTFail("VViewFactory did not store a RotationWrapper for the rotate event")
            fatalError("unreachable")
        }
        return (view, wrapper)
    }

    // MARK: - Pinch: native-driven applies the transform

    func testNativeDrivenPinchAppliesTransform() {
        var lastPayload: [String: Any]?
        let (view, wrapper) = makePinchView(nativeDriven: true) { lastPayload = $0 }

        wrapper.handlePinch(view: view, state: .began, scale: 1, velocity: 0)
        wrapper.handlePinch(view: view, state: .changed, scale: 2, velocity: 0)

        XCTAssertEqual(view.transform.a, 2, accuracy: 0.001, "native-driven pinch must scale X on the UI thread")
        XCTAssertEqual(view.transform.d, 2, accuracy: 0.001, "native-driven pinch must scale Y on the UI thread")

        // The event must still be forwarded to JS for state tracking.
        XCTAssertEqual(lastPayload?["state"] as? String, "changed")
        XCTAssertEqual(lastPayload?["scale"] as? CGFloat, 2)
    }

    func testNativeDrivenPinchLeavesTransformAtLastScaleOnEnded() {
        let (view, wrapper) = makePinchView(nativeDriven: true) { _ in }

        wrapper.handlePinch(view: view, state: .began, scale: 1, velocity: 0)
        wrapper.handlePinch(view: view, state: .changed, scale: 3, velocity: 0)
        wrapper.handlePinch(view: view, state: .ended, scale: 3, velocity: 0)

        XCTAssertEqual(view.transform.a, 3, accuracy: 0.001, "ended must keep the last scaled X size")
        XCTAssertEqual(view.transform.d, 3, accuracy: 0.001, "ended must keep the last scaled Y size")
    }

    func testNativeDrivenPinchPreservesBaseTransform() {
        let (view, wrapper) = makePinchView(nativeDriven: true) { _ in }
        // A style-applied 2D transform present before the pinch begins.
        view.transform = CGAffineTransform(scaleX: 2, y: 2)

        wrapper.handlePinch(view: view, state: .began, scale: 1, velocity: 0)
        wrapper.handlePinch(view: view, state: .changed, scale: 3, velocity: 0)

        // The gesture scale accumulates on top of the base scale (2 * 3 = 6).
        XCTAssertEqual(view.transform.a, 6, accuracy: 0.001, "pinch scale must accumulate on the base scaleX")
        XCTAssertEqual(view.transform.d, 6, accuracy: 0.001, "pinch scale must accumulate on the base scaleY")
    }

    func testPinchWithoutNativeDriveDoesNotChangeTransform() {
        var eventCount = 0
        let (view, wrapper) = makePinchView(nativeDriven: false) { _ in eventCount += 1 }

        wrapper.handlePinch(view: view, state: .began, scale: 1, velocity: 0)
        wrapper.handlePinch(view: view, state: .changed, scale: 2.5, velocity: 0)
        wrapper.handlePinch(view: view, state: .ended, scale: 2.5, velocity: 0)

        XCTAssertTrue(view.transform.isIdentity, "without nativeDrivenGestures the transform must not change")
        XCTAssertEqual(eventCount, 3, "the pinch event must still fire to JS for every state")
    }

    // MARK: - Rotate: native-driven applies the transform

    func testNativeDrivenRotateAppliesTransform() {
        var lastPayload: [String: Any]?
        let (view, wrapper) = makeRotateView(nativeDriven: true) { lastPayload = $0 }

        let angle = CGFloat.pi / 2
        wrapper.handleRotation(view: view, state: .began, rotation: 0, velocity: 0)
        wrapper.handleRotation(view: view, state: .changed, rotation: angle, velocity: 0)

        // cos(pi/2) == 0, sin(pi/2) == 1
        XCTAssertEqual(view.transform.a, 0, accuracy: 0.001, "native-driven rotate must set cos(angle) on the UI thread")
        XCTAssertEqual(view.transform.b, 1, accuracy: 0.001, "native-driven rotate must set sin(angle) on the UI thread")

        // The event must still be forwarded to JS for state tracking.
        XCTAssertEqual(lastPayload?["state"] as? String, "changed")
        XCTAssertEqual(lastPayload?["rotation"] as? CGFloat, angle)
    }

    func testNativeDrivenRotateLeavesTransformAtLastAngleOnEnded() {
        let (view, wrapper) = makeRotateView(nativeDriven: true) { _ in }

        let angle = CGFloat.pi / 4
        wrapper.handleRotation(view: view, state: .began, rotation: 0, velocity: 0)
        wrapper.handleRotation(view: view, state: .changed, rotation: angle, velocity: 0)
        wrapper.handleRotation(view: view, state: .ended, rotation: angle, velocity: 0)

        XCTAssertEqual(view.transform.a, cos(angle), accuracy: 0.001, "ended must keep the last rotated angle")
        XCTAssertEqual(view.transform.b, sin(angle), accuracy: 0.001, "ended must keep the last rotated angle")
    }

    func testNativeDrivenRotatePreservesBaseTransform() {
        let (view, wrapper) = makeRotateView(nativeDriven: true) { _ in }
        // A style-applied scale present before the rotation begins.
        view.transform = CGAffineTransform(scaleX: 2, y: 2)

        let angle = CGFloat.pi / 2
        wrapper.handleRotation(view: view, state: .began, rotation: 0, velocity: 0)
        wrapper.handleRotation(view: view, state: .changed, rotation: angle, velocity: 0)

        // Scale 2 rotated by pi/2: b == 2 (scale preserved, rotation applied).
        XCTAssertEqual(view.transform.b, 2, accuracy: 0.001, "rotation must accumulate on the base scale")
        XCTAssertEqual(view.transform.c, -2, accuracy: 0.001, "rotation must accumulate on the base scale")
    }

    func testRotateWithoutNativeDriveDoesNotChangeTransform() {
        var eventCount = 0
        let (view, wrapper) = makeRotateView(nativeDriven: false) { _ in eventCount += 1 }

        wrapper.handleRotation(view: view, state: .began, rotation: 0, velocity: 0)
        wrapper.handleRotation(view: view, state: .changed, rotation: 1.2, velocity: 0)
        wrapper.handleRotation(view: view, state: .ended, rotation: 1.2, velocity: 0)

        XCTAssertTrue(view.transform.isIdentity, "without nativeDrivenGestures the transform must not change")
        XCTAssertEqual(eventCount, 3, "the rotate event must still fire to JS for every state")
    }
}
#endif
