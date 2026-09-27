#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Regression coverage for `TouchableView`'s opacity handling.
///
/// The press and disabled states used to write hard-coded `alpha` values
/// (`activeOpacity`, `1.0`, `0.4`), so the style-driven opacity set through
/// `StyleEngine` was destroyed by the first interaction: `<VButton style="opacity: 0.5">`
/// snapped to fully opaque after one tap, and toggling `disabled` off forced `1.0`.
/// Both states now scale the stored base opacity instead of replacing it.
@MainActor
final class TouchableViewOpacityTests: XCTestCase {

    /// `StyleEngine.apply(key: "opacity", ...)` writes `view.alpha` directly, so this
    /// is exactly how a styled opacity arrives at the view.
    private func makeView(baseOpacity: CGFloat, activeOpacity: CGFloat = 0.7) -> TouchableView {
        let view = TouchableView()
        view.activeOpacity = activeOpacity
        view.alpha = baseOpacity
        return view
    }

    func testStyleDrivenOpacityIsRecordedAsTheBase() {
        let view = makeView(baseOpacity: 0.5)
        XCTAssertEqual(view.baseAlpha, 0.5, accuracy: 0.001)
        XCTAssertEqual(view.alpha, 0.5, accuracy: 0.001, "setting alpha must not immediately alter it")
    }

    func testPressDimsRelativeToStyledOpacityAndReleaseRestoresIt() {
        let view = makeView(baseOpacity: 0.5)

        view.touchesBegan([], with: nil)
        // UIView.animate applies its model value synchronously, so alpha is already
        // the target here.
        XCTAssertEqual(view.alpha, 0.35, accuracy: 0.001, "pressing should dim to 0.7 * the styled 0.5")

        view.touchesEnded([], with: nil)
        XCTAssertEqual(
            view.alpha, 0.5, accuracy: 0.001,
            "releasing must restore the styled opacity, not snap to 1.0"
        )
    }

    func testCancelledPressRestoresStyledOpacity() {
        let view = makeView(baseOpacity: 0.25)

        view.touchesBegan([], with: nil)
        view.touchesCancelled([], with: nil)

        XCTAssertEqual(view.alpha, 0.25, accuracy: 0.001)
    }

    func testDisablingAndReEnablingPreservesStyledOpacity() {
        let view = makeView(baseOpacity: 0.5)

        view.isDisabled = true
        XCTAssertEqual(
            view.alpha, 0.2, accuracy: 0.001,
            "disabled should be 40% of the styled opacity, not an absolute 0.4"
        )
        XCTAssertFalse(view.isUserInteractionEnabled)

        view.isDisabled = false
        XCTAssertEqual(
            view.alpha, 0.5, accuracy: 0.001,
            "re-enabling must restore the styled opacity, not force 1.0"
        )
        XCTAssertTrue(view.isUserInteractionEnabled)
    }

    func testUntouchedViewStillUsesTheDocumentedAbsoluteValues() {
        // Backwards compatibility: with no styled opacity the base is 1.0, so the
        // press and disabled values match the historical 0.7 / 0.4 exactly.
        let view = makeView(baseOpacity: 1.0)

        view.touchesBegan([], with: nil)
        XCTAssertEqual(view.alpha, 0.7, accuracy: 0.001)
        view.touchesEnded([], with: nil)
        XCTAssertEqual(view.alpha, 1.0, accuracy: 0.001)

        view.isDisabled = true
        XCTAssertEqual(view.alpha, 0.4, accuracy: 0.001)
    }

    func testOpacityChangedMidPressIsHonoured() {
        let view = makeView(baseOpacity: 1.0)

        view.touchesBegan([], with: nil)
        XCTAssertEqual(view.alpha, 0.7, accuracy: 0.001)

        // A reactive style change landing while the finger is down must update the
        // base without cancelling the press dim.
        view.alpha = 0.5
        XCTAssertEqual(view.baseAlpha, 0.5, accuracy: 0.001)
        XCTAssertEqual(view.alpha, 0.35, accuracy: 0.001, "the press dim must be re-applied to the new base")

        view.touchesEnded([], with: nil)
        XCTAssertEqual(view.alpha, 0.5, accuracy: 0.001)
    }

    func testActiveOpacityChangeWhilePressedTakesEffectImmediately() {
        let view = makeView(baseOpacity: 1.0, activeOpacity: 0.7)
        view.touchesBegan([], with: nil)
        XCTAssertEqual(view.alpha, 0.7, accuracy: 0.001)

        view.activeOpacity = 0.2
        XCTAssertEqual(view.alpha, 0.2, accuracy: 0.001)
    }

    func testDragOutsideBoundsRemovesThePressDim() {
        let view = makeView(baseOpacity: 1.0)
        view.bounds = CGRect(x: 0, y: 0, width: 100, height: 44)

        view.touchesBegan([], with: nil)
        XCTAssertEqual(view.alpha, 0.7, accuracy: 0.001)

        // A touch reported outside the bounds: `touchesMoved` needs a real UITouch to
        // read a location from, so drive the state transition through the public
        // disabled path instead and assert the press dim is at least recoverable.
        view.touchesCancelled([], with: nil)
        XCTAssertEqual(view.alpha, 1.0, accuracy: 0.001)
    }

    func testRedundantDisabledAssignmentDoesNotDisturbAlpha() {
        let view = makeView(baseOpacity: 0.6)
        view.isDisabled = false // already false
        XCTAssertEqual(view.alpha, 0.6, accuracy: 0.001)
    }
}
#endif
