#if canImport(AppKit)
import XCTest
import AppKit
@testable import VueNativeMacOS

/// Tests for the pure `HotReloadStatus` -> badge appearance mapping and the
/// `HotReloadStatusView` that applies it. NSView counterpart of the iOS
/// `HotReloadStatusViewTests` -- same semantics, mapped onto AppKit.
@MainActor
final class HotReloadStatusViewTests: XCTestCase {

    // MARK: - Pure mapping: connecting

    func testConnectingAtZeroAttemptsIsOrange() {
        let content = HotReloadStatusView.content(for: .connecting(attempt: 0))
        XCTAssertEqual(content.text, "Connecting…")
        XCTAssertEqual(content.tone, .connecting)
    }

    func testConnectingAtThresholdStaysOrange() {
        // attempt <= 3 is documented as still "connecting".
        let content = HotReloadStatusView.content(for: .connecting(attempt: 3))
        XCTAssertEqual(content.tone, .connecting)
    }

    func testConnectingPastThresholdBecomesDisconnectedRed() {
        let content = HotReloadStatusView.content(for: .connecting(attempt: 4))
        XCTAssertEqual(content.text, "Disconnected — check `vue-native dev`")
        XCTAssertEqual(content.tone, .disconnected)
    }

    func testConnectingWellPastThresholdStaysDisconnectedRed() {
        let content = HotReloadStatusView.content(for: .connecting(attempt: 50))
        XCTAssertEqual(content.tone, .disconnected)
    }

    // MARK: - Pure mapping: connected

    func testConnectedIsGreen() {
        let content = HotReloadStatusView.content(for: .connected)
        XCTAssertEqual(content.text, "Connected")
        XCTAssertEqual(content.tone, .connected)
    }

    // MARK: - Auto-hide

    func testOnlyConnectedAutoHides() {
        XCTAssertTrue(HotReloadStatusView.shouldAutoHide(for: .connected))
        XCTAssertFalse(HotReloadStatusView.shouldAutoHide(for: .connecting(attempt: 0)))
        XCTAssertFalse(HotReloadStatusView.shouldAutoHide(for: .connecting(attempt: 10)))
    }

    // MARK: - View behavior

    func testViewStartsHidden() {
        let view = HotReloadStatusView(frame: .zero)
        XCTAssertTrue(view.isHidden, "badge should start hidden until a status is applied")
    }

    func testViewIsNonInteractive() {
        let view = HotReloadStatusView(frame: NSRect(x: 0, y: 0, width: 100, height: 30))
        XCTAssertNil(view.hitTest(NSPoint(x: 50, y: 15)), "badge must never intercept clicks meant for the app")
    }

    func testApplyConnectingShowsBadgeWithLabel() {
        let view = HotReloadStatusView(frame: .zero)
        view.apply(.connecting(attempt: 1))

        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(view.label.stringValue, "Connecting…")
    }

    func testApplyDisconnectedShowsBadge() {
        let view = HotReloadStatusView(frame: .zero)
        view.apply(.connecting(attempt: 5))

        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(view.label.stringValue, "Disconnected — check `vue-native dev`")
    }

    func testApplyReappearsAfterBeingHidden() {
        // Regression: the badge must survive reconnections -- reappearing
        // after the "Connected" auto-hide once a fresh disconnect happens.
        let view = HotReloadStatusView(frame: .zero)
        view.apply(.connected)
        view.isHidden = true // simulate the auto-hide timer having already fired

        view.apply(.connecting(attempt: 1))
        XCTAssertFalse(view.isHidden, "a new status must always reveal the badge again")
    }

    func testApplyConnectedAutoHidesAfterDelay() async {
        let view = HotReloadStatusView(frame: .zero)
        view.apply(.connected)
        XCTAssertFalse(view.isHidden, "badge should be visible immediately on connect")
        XCTAssertEqual(view.label.stringValue, "Connected")

        let expectation = expectation(description: "badge auto-hides")
        DispatchQueue.main.asyncAfter(deadline: .now() + HotReloadStatusView.autoHideDelay + 0.3) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: HotReloadStatusView.autoHideDelay + 1.0)

        XCTAssertTrue(view.isHidden, "badge should auto-hide ~2s after connecting")
    }
}
#endif
