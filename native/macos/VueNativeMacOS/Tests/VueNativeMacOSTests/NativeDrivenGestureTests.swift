#if canImport(AppKit)
import AppKit
import XCTest
@testable import VueNativeMacOS

/// Tests for native-driven pan gestures: when a view marks `pan` as native-driven
/// (via the `nativeDrivenGestures` prop), the pan handler applies the translation
/// directly to the view's layer transform on the UI thread, while still delivering
/// the `pan` event to JS.
@MainActor
final class NativeDrivenGestureTests: XCTestCase {

    // MARK: - Helpers

    /// Drive the pan handler core the same way a recognizer would, state by state.
    private func drivePan(
        _ wrapper: PanGestureWrapper,
        on view: NSView,
        translation: CGPoint,
        state: NSGestureRecognizer.State
    ) {
        wrapper.process(view: view, translation: translation, velocity: .zero, state: state)
    }

    // MARK: - Transform application

    func testNativeDrivenPanUpdatesLayerTransform() {
        let view = FlippedView()
        view.nativeDrivenGestures = ["pan"]
        let wrapper = PanGestureWrapper(handler: { _ in })

        drivePan(wrapper, on: view, translation: .zero, state: .began)
        drivePan(wrapper, on: view, translation: CGPoint(x: 30, y: 40), state: .changed)

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer transform after a native-driven pan")
        }
        XCTAssertEqual(transform.m41, 30, accuracy: 0.001, "translation X should be applied to the layer")
        XCTAssertEqual(transform.m42, 40, accuracy: 0.001, "translation Y should be applied to the layer")
    }

    func testPanWithoutNativeDriveLeavesTransformUnchanged() {
        let view = FlippedView()
        // No nativeDrivenGestures prop set.
        let wrapper = PanGestureWrapper(handler: { _ in })

        drivePan(wrapper, on: view, translation: .zero, state: .began)
        drivePan(wrapper, on: view, translation: CGPoint(x: 30, y: 40), state: .changed)

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer on the view")
        }
        XCTAssertTrue(CATransform3DIsIdentity(transform), "non-native-driven pan must not touch the transform")
    }

    func testNativeDrivenEndedLeavesLastPosition() {
        let view = FlippedView()
        view.nativeDrivenGestures = ["pan"]
        let wrapper = PanGestureWrapper(handler: { _ in })

        drivePan(wrapper, on: view, translation: .zero, state: .began)
        drivePan(wrapper, on: view, translation: CGPoint(x: 10, y: 20), state: .changed)
        drivePan(wrapper, on: view, translation: CGPoint(x: 50, y: 60), state: .ended)

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer transform after pan ended")
        }
        XCTAssertEqual(transform.m41, 50, accuracy: 0.001, "ended should retain the last translation X")
        XCTAssertEqual(transform.m42, 60, accuracy: 0.001, "ended should retain the last translation Y")
    }

    func testNativeDrivenPanPreservesStyleTransform() {
        let view = FlippedView()
        // StyleEngine writes `transform` straight to layer.transform; a native-driven pan
        // must compose on top of it rather than clobber it.
        StyleEngine.apply(key: "transform", value: [["scale": 2.0]], to: view)
        view.nativeDrivenGestures = ["pan"]
        let wrapper = PanGestureWrapper(handler: { _ in })

        drivePan(wrapper, on: view, translation: .zero, state: .began)
        drivePan(wrapper, on: view, translation: CGPoint(x: 30, y: 40), state: .changed)

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer transform")
        }
        XCTAssertEqual(transform.m11, 2.0, accuracy: 0.001, "style scale must be preserved")
        XCTAssertEqual(transform.m22, 2.0, accuracy: 0.001, "style scale must be preserved")
        XCTAssertEqual(transform.m41, 30, accuracy: 0.001, "translation X composed in superview space")
        XCTAssertEqual(transform.m42, 40, accuracy: 0.001, "translation Y composed in superview space")
    }

    // MARK: - JS event delivery (regression guard)

    func testNativeDrivenPanStillFiresJSEvent() {
        let view = FlippedView()
        view.nativeDrivenGestures = ["pan"]
        var payloads: [[String: Any]] = []
        let wrapper = PanGestureWrapper(handler: { payload in
            if let dict = payload as? [String: Any] { payloads.append(dict) }
        })

        drivePan(wrapper, on: view, translation: CGPoint(x: 30, y: 40), state: .changed)

        XCTAssertEqual(payloads.count, 1, "native-driven pan must still emit the JS event")
        XCTAssertEqual(payloads.first?["translationX"] as? CGFloat, 30)
        XCTAssertEqual(payloads.first?["translationY"] as? CGFloat, 40)
        XCTAssertEqual(payloads.first?["state"] as? String, "changed")
    }

    func testNonNativeDrivenPanStillFiresJSEvent() {
        let view = FlippedView()
        var payloads: [[String: Any]] = []
        let wrapper = PanGestureWrapper(handler: { payload in
            if let dict = payload as? [String: Any] { payloads.append(dict) }
        })

        drivePan(wrapper, on: view, translation: CGPoint(x: 5, y: 6), state: .changed)

        XCTAssertEqual(payloads.count, 1, "regular pan must keep emitting the JS event")
        XCTAssertEqual(payloads.first?["state"] as? String, "changed")
    }

    // MARK: - Prop handling via the factory

    func testUpdatePropStoresNativeDrivenGestures() {
        let factory = VViewFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "nativeDrivenGestures", value: ["pan"])
        XCTAssertEqual(view.nativeDrivenGestures, ["pan"])

        // Clearing the prop (nil) empties the set.
        factory.updateProp(view: view, key: "nativeDrivenGestures", value: nil)
        XCTAssertTrue(view.nativeDrivenGestures.isEmpty)
    }

    func testUpdatePropNativeDrivenDoesNotRouteToStyleEngine() {
        let factory = VViewFactory()
        let view = factory.createView()

        // Should be stored as gesture config and must not disturb the layer transform.
        factory.updateProp(view: view, key: "nativeDrivenGestures", value: ["pan"])

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer on the view")
        }
        XCTAssertTrue(CATransform3DIsIdentity(transform))
    }

    // MARK: - Native-driven pinch (magnification)

    func testNativeDrivenPinchUpdatesLayerTransform() {
        let view = FlippedView()
        view.nativeDrivenGestures = ["pinch"]
        let wrapper = MagnificationGestureWrapper(handler: { _ in })

        wrapper.process(view: view, magnification: 0, state: .began)
        wrapper.process(view: view, magnification: 0.5, state: .changed)

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer transform after a native-driven pinch")
        }
        // magnification 0.5 -> scale 1.5 applied on the X and Y axes.
        XCTAssertEqual(transform.m11, 1.5, accuracy: 0.001, "scale X should be applied to the layer")
        XCTAssertEqual(transform.m22, 1.5, accuracy: 0.001, "scale Y should be applied to the layer")
    }

    func testPinchWithoutNativeDriveLeavesTransformUnchanged() {
        let view = FlippedView()
        // No nativeDrivenGestures prop set.
        let wrapper = MagnificationGestureWrapper(handler: { _ in })

        wrapper.process(view: view, magnification: 0, state: .began)
        wrapper.process(view: view, magnification: 0.5, state: .changed)

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer on the view")
        }
        XCTAssertTrue(CATransform3DIsIdentity(transform), "non-native-driven pinch must not touch the transform")
    }

    func testNativeDrivenPinchPreservesStyleTransform() {
        let view = FlippedView()
        // StyleEngine writes `transform` straight to layer.transform; a native-driven
        // pinch must compose on top of it rather than clobber it.
        StyleEngine.apply(key: "transform", value: [["scale": 2.0]], to: view)
        view.nativeDrivenGestures = ["pinch"]
        let wrapper = MagnificationGestureWrapper(handler: { _ in })

        wrapper.process(view: view, magnification: 0, state: .began)
        wrapper.process(view: view, magnification: 0.5, state: .changed)

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer transform")
        }
        // style scale 2 * pinch scale 1.5 = 3
        XCTAssertEqual(transform.m11, 3.0, accuracy: 0.001, "style scale composed with pinch scale (X)")
        XCTAssertEqual(transform.m22, 3.0, accuracy: 0.001, "style scale composed with pinch scale (Y)")
    }

    func testNativeDrivenPinchStillFiresJSEvent() {
        let view = FlippedView()
        view.nativeDrivenGestures = ["pinch"]
        var payloads: [[String: Any]] = []
        let wrapper = MagnificationGestureWrapper(handler: { payload in
            if let dict = payload as? [String: Any] { payloads.append(dict) }
        })

        wrapper.process(view: view, magnification: 0.5, state: .changed)

        XCTAssertEqual(payloads.count, 1, "native-driven pinch must still emit the JS event")
        XCTAssertEqual(payloads.first?["scale"] as? CGFloat, 1.5)
        XCTAssertEqual(payloads.first?["state"] as? String, "changed")
    }

    // MARK: - Native-driven rotate

    func testNativeDrivenRotateUpdatesLayerTransform() {
        let view = FlippedView()
        view.nativeDrivenGestures = ["rotate"]
        let wrapper = RotationGestureWrapper(handler: { _ in })

        wrapper.process(view: view, rotation: 0, state: .began)
        wrapper.process(view: view, rotation: .pi / 2, state: .changed)

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer transform after a native-driven rotate")
        }
        // Rotation of π/2 about the Z axis: cos≈0, sin≈1.
        XCTAssertEqual(transform.m11, 0, accuracy: 0.001, "cos(π/2) on m11")
        XCTAssertEqual(transform.m12, 1, accuracy: 0.001, "sin(π/2) on m12")
        XCTAssertEqual(transform.m21, -1, accuracy: 0.001, "-sin(π/2) on m21")
        XCTAssertEqual(transform.m22, 0, accuracy: 0.001, "cos(π/2) on m22")
    }

    func testRotateWithoutNativeDriveLeavesTransformUnchanged() {
        let view = FlippedView()
        // No nativeDrivenGestures prop set.
        let wrapper = RotationGestureWrapper(handler: { _ in })

        wrapper.process(view: view, rotation: 0, state: .began)
        wrapper.process(view: view, rotation: .pi / 2, state: .changed)

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer on the view")
        }
        XCTAssertTrue(CATransform3DIsIdentity(transform), "non-native-driven rotate must not touch the transform")
    }

    func testNativeDrivenRotatePreservesStyleTransform() {
        let view = FlippedView()
        // A style scale must survive a native-driven rotation (composed as the base).
        StyleEngine.apply(key: "transform", value: [["scale": 2.0]], to: view)
        view.nativeDrivenGestures = ["rotate"]
        let wrapper = RotationGestureWrapper(handler: { _ in })

        wrapper.process(view: view, rotation: 0, state: .began)
        wrapper.process(view: view, rotation: .pi / 2, state: .changed)

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer transform")
        }
        // base scale 2 rotated by π/2: m11 = 2*cos ≈ 0, m12 = 2*sin ≈ 2.
        XCTAssertEqual(transform.m11, 0, accuracy: 0.001, "scaled cos(π/2) on m11")
        XCTAssertEqual(transform.m12, 2, accuracy: 0.001, "scaled sin(π/2) on m12")
        XCTAssertEqual(transform.m21, -2, accuracy: 0.001, "scaled -sin(π/2) on m21")
        XCTAssertEqual(transform.m22, 0, accuracy: 0.001, "scaled cos(π/2) on m22")
    }

    func testNativeDrivenRotateStillFiresJSEvent() {
        let view = FlippedView()
        view.nativeDrivenGestures = ["rotate"]
        var payloads: [[String: Any]] = []
        let wrapper = RotationGestureWrapper(handler: { payload in
            if let dict = payload as? [String: Any] { payloads.append(dict) }
        })

        wrapper.process(view: view, rotation: .pi / 4, state: .changed)

        XCTAssertEqual(payloads.count, 1, "native-driven rotate must still emit the JS event")
        XCTAssertEqual(payloads.first?["rotation"] as? CGFloat, .pi / 4)
        XCTAssertEqual(payloads.first?["state"] as? String, "changed")
    }
}
#endif
