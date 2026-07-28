#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Tests for the native swipe-back edge-pan gesture on ``VueNativeViewController``.
///
/// These exercise the gesture configuration and trigger logic directly rather
/// than driving the full view-controller lifecycle, so they do not touch the
/// shared JS runtime / bridge singletons.
@MainActor
final class VueNativeViewControllerGestureTests: XCTestCase {

    func testSwipeBackGestureIsLeftEdgePan() {
        let controller = VueNativeViewController()
        let gesture = controller.makeSwipeBackGesture()

        XCTAssertTrue(gesture is UIScreenEdgePanGestureRecognizer, "swipe-back must be a screen-edge pan")
        XCTAssertEqual(gesture.edges, .left, "swipe-back must recognize pans starting at the left edge")
    }

    func testSwipeBackTriggersPastTranslationThreshold() {
        XCTAssertTrue(
            VueNativeViewController.shouldTriggerSwipeBack(translationX: 90, viewWidth: 400),
            "a translation beyond the 80pt threshold should trigger swipe-back"
        )
        XCTAssertFalse(
            VueNativeViewController.shouldTriggerSwipeBack(translationX: 30, viewWidth: 400),
            "a small translation should not trigger swipe-back"
        )
    }

    func testSwipeBackTriggersPastWidthFractionThreshold() {
        // 60pt is below the 80pt absolute threshold but beyond 50% of a 100pt width.
        XCTAssertTrue(
            VueNativeViewController.shouldTriggerSwipeBack(translationX: 60, viewWidth: 100),
            "a translation beyond 50% of the view width should trigger swipe-back"
        )
        XCTAssertFalse(
            VueNativeViewController.shouldTriggerSwipeBack(translationX: 40, viewWidth: 100),
            "a translation below both thresholds should not trigger swipe-back"
        )
    }

    func testSwipeBackIgnoresNegativeTranslation() {
        XCTAssertFalse(
            VueNativeViewController.shouldTriggerSwipeBack(translationX: -120, viewWidth: 400),
            "a leftward (negative) translation must not trigger swipe-back"
        )
    }
}
#endif
