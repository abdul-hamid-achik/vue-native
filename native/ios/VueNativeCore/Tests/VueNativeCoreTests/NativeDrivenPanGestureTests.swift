#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Tests for native-driven pan gestures.
///
/// When a view's `nativeDrivenGestures` prop contains `"pan"`, the pan handler must
/// apply the drag translation directly to the view transform on the UI thread (no JS
/// round-trip per frame) while still forwarding the `pan` event to JS. Without the
/// prop, the transform must be left untouched (the pre-existing JS-driven behavior).
///
/// The gesture lifecycle is driven through ``PanWrapper/handlePan(view:state:translation:velocity:)``
/// — the same code path the recognizer callback uses — because `UIPanGestureRecognizer`
/// translation cannot be synthesized in a unit test without a UI-test target.
@MainActor
final class NativeDrivenPanGestureTests: XCTestCase {

    // MARK: - Helpers

    /// Build a VView, wire a `pan` listener through the factory, and return the view
    /// plus the factory-installed ``PanWrapper`` so tests can drive the real wiring.
    private func makePanView(
        nativeDriven: Bool,
        onEvent: @escaping ([String: Any]) -> Void
    ) -> (view: UIView, wrapper: PanWrapper) {
        let factory = VViewFactory()
        let view = factory.createView()
        if nativeDriven {
            factory.updateProp(view: view, key: "nativeDrivenGestures", value: ["pan"])
        }
        factory.addEventListener(view: view, event: "pan") { payload in
            if let dict = payload as? [String: Any] {
                onEvent(dict)
            }
        }
        guard let wrapper = GestureStorage.getObject(for: view, event: "pan") as? PanWrapper else {
            XCTFail("VViewFactory did not store a PanWrapper for the pan event")
            fatalError("unreachable")
        }
        return (view, wrapper)
    }

    // MARK: - Native-driven applies the transform

    func testNativeDrivenPanAppliesTransform() {
        var lastPayload: [String: Any]?
        let (view, wrapper) = makePanView(nativeDriven: true) { lastPayload = $0 }

        wrapper.handlePan(view: view, state: .began, translation: .zero, velocity: .zero)
        wrapper.handlePan(view: view, state: .changed, translation: CGPoint(x: 50, y: 30), velocity: .zero)

        XCTAssertEqual(view.transform.tx, 50, accuracy: 0.001, "native-driven pan must translate X on the UI thread")
        XCTAssertEqual(view.transform.ty, 30, accuracy: 0.001, "native-driven pan must translate Y on the UI thread")

        // The event must still be forwarded to JS for state tracking.
        XCTAssertEqual(lastPayload?["state"] as? String, "changed")
        XCTAssertEqual(lastPayload?["translationX"] as? CGFloat, 50)
        XCTAssertEqual(lastPayload?["translationY"] as? CGFloat, 30)
    }

    func testNativeDrivenPanLeavesTransformAtLastPositionOnEnded() {
        let (view, wrapper) = makePanView(nativeDriven: true) { _ in }

        wrapper.handlePan(view: view, state: .began, translation: .zero, velocity: .zero)
        wrapper.handlePan(view: view, state: .changed, translation: CGPoint(x: 80, y: -20), velocity: .zero)
        wrapper.handlePan(view: view, state: .ended, translation: CGPoint(x: 80, y: -20), velocity: .zero)

        XCTAssertEqual(view.transform.tx, 80, accuracy: 0.001, "ended must keep the last dragged X position")
        XCTAssertEqual(view.transform.ty, -20, accuracy: 0.001, "ended must keep the last dragged Y position")
    }

    func testNativeDrivenPanPreservesBaseTransform() {
        let (view, wrapper) = makePanView(nativeDriven: true) { _ in }
        // A style-applied 2D transform present before the drag begins.
        view.transform = CGAffineTransform(scaleX: 2, y: 2)

        wrapper.handlePan(view: view, state: .began, translation: .zero, velocity: .zero)
        wrapper.handlePan(view: view, state: .changed, translation: CGPoint(x: 10, y: 5), velocity: .zero)

        // Scale is preserved and the translation is added in superview space.
        XCTAssertEqual(view.transform.a, 2, accuracy: 0.001, "base scaleX must be preserved")
        XCTAssertEqual(view.transform.d, 2, accuracy: 0.001, "base scaleY must be preserved")
        XCTAssertEqual(view.transform.tx, 10, accuracy: 0.001, "translation X must accumulate on the base transform")
        XCTAssertEqual(view.transform.ty, 5, accuracy: 0.001, "translation Y must accumulate on the base transform")
    }

    // MARK: - Without native-drive the transform is untouched

    func testPanWithoutNativeDriveDoesNotChangeTransform() {
        var eventCount = 0
        let (view, wrapper) = makePanView(nativeDriven: false) { _ in eventCount += 1 }

        wrapper.handlePan(view: view, state: .began, translation: .zero, velocity: .zero)
        wrapper.handlePan(view: view, state: .changed, translation: CGPoint(x: 50, y: 30), velocity: .zero)
        wrapper.handlePan(view: view, state: .ended, translation: CGPoint(x: 50, y: 30), velocity: .zero)

        XCTAssertTrue(view.transform.isIdentity, "without nativeDrivenGestures the transform must not change")
        XCTAssertEqual(eventCount, 3, "the pan event must still fire to JS for every state")
    }

    // MARK: - Prop handling

    func testUpdatePropStoresAndClearsNativeDrivenGestures() {
        let factory = VViewFactory()
        let view = factory.createView()

        XCTAssertFalse(NativeDrivenGestures.contains("pan", in: view))

        factory.updateProp(view: view, key: "nativeDrivenGestures", value: ["pan"])
        XCTAssertTrue(NativeDrivenGestures.contains("pan", in: view))

        // Removing the prop (nil) clears the native-driven set.
        factory.updateProp(view: view, key: "nativeDrivenGestures", value: nil)
        XCTAssertFalse(NativeDrivenGestures.contains("pan", in: view))
    }

    func testUpdatePropAcceptsHeterogeneousArray() {
        let factory = VViewFactory()
        let view = factory.createView()

        // A bridged NSArray may arrive as [Any]; non-string entries are ignored.
        factory.updateProp(view: view, key: "nativeDrivenGestures", value: ["pan", 42, "pinch"] as [Any])
        XCTAssertTrue(NativeDrivenGestures.contains("pan", in: view))
        XCTAssertTrue(NativeDrivenGestures.contains("pinch", in: view))
    }
}
#endif
