#if canImport(AppKit)
import AppKit
import XCTest
@testable import VueNativeMacOS

@MainActor
final class HotReloadManagerTests: XCTestCase {

    override func tearDown() {
        HotReloadManager.shared.disconnect()
        HotReloadManager.shared.onStatusChange = nil
        super.tearDown()
    }

    // MARK: - Exponential backoff

    func testReconnectDelayDoublesPerAttempt() {
        XCTAssertEqual(HotReloadManager.reconnectDelay(forAttempt: 1), 1.0, accuracy: 0.0001)
        XCTAssertEqual(HotReloadManager.reconnectDelay(forAttempt: 2), 2.0, accuracy: 0.0001)
        XCTAssertEqual(HotReloadManager.reconnectDelay(forAttempt: 3), 4.0, accuracy: 0.0001)
        XCTAssertEqual(HotReloadManager.reconnectDelay(forAttempt: 4), 8.0, accuracy: 0.0001)
        XCTAssertEqual(HotReloadManager.reconnectDelay(forAttempt: 5), 16.0, accuracy: 0.0001)
    }

    func testReconnectDelayIsCappedAtMaximum() {
        // 2^5 = 32 would exceed the 30s cap, so attempt 6 onwards is clamped.
        XCTAssertEqual(HotReloadManager.reconnectDelay(forAttempt: 6), 30.0, accuracy: 0.0001)
        XCTAssertEqual(HotReloadManager.reconnectDelay(forAttempt: 7), 30.0, accuracy: 0.0001)
        XCTAssertEqual(HotReloadManager.reconnectDelay(forAttempt: 10), 30.0, accuracy: 0.0001)
    }

    func testReconnectDelayNeverGivesUpOrExceedsCap() {
        // Very large attempt counts must stay finite and capped -- the manager
        // retries indefinitely, so the delay must never blow up or go to zero.
        for attempt in [50, 100, 1_000, 1_000_000] {
            let delay = HotReloadManager.reconnectDelay(forAttempt: attempt)
            XCTAssertTrue(delay.isFinite, "delay for attempt \(attempt) must be finite")
            XCTAssertGreaterThan(delay, 0, "delay for attempt \(attempt) must be positive")
            XCTAssertLessThanOrEqual(delay, 30.0, "delay for attempt \(attempt) must respect the cap")
        }
    }

    func testReconnectDelayIsMonotonicallyNonDecreasingUntilCap() {
        var previous = HotReloadManager.reconnectDelay(forAttempt: 1)
        for attempt in 2...20 {
            let current = HotReloadManager.reconnectDelay(forAttempt: attempt)
            XCTAssertGreaterThanOrEqual(current, previous, "delay must not shrink at attempt \(attempt)")
            previous = current
        }
    }

    func testReconnectDelayHonorsCustomBounds() {
        XCTAssertEqual(
            HotReloadManager.reconnectDelay(forAttempt: 1, base: 0.5, max: 5.0),
            0.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            HotReloadManager.reconnectDelay(forAttempt: 4, base: 0.5, max: 5.0),
            4.0,
            accuracy: 0.0001
        )
        // 0.5 * 2^4 = 8.0 -> capped at 5.0
        XCTAssertEqual(
            HotReloadManager.reconnectDelay(forAttempt: 5, base: 0.5, max: 5.0),
            5.0,
            accuracy: 0.0001
        )
    }

    func testReconnectDelayHandlesNonPositiveAttempt() {
        // attempt <= 1 falls back to the base delay rather than crashing.
        XCTAssertEqual(HotReloadManager.reconnectDelay(forAttempt: 0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(HotReloadManager.reconnectDelay(forAttempt: -3), 1.0, accuracy: 0.0001)
    }

    // MARK: - Status callback

    /// `connect(to:)` emits `.connecting(attempt: 0)` synchronously, before
    /// any network activity is scheduled, so this is deterministic without a
    /// real dev server. Reconnect/connected transitions depend on real
    /// socket activity and are covered by the `HotReloadStatus` enum mapping
    /// tests instead (`HotReloadStatusViewTests`).
    func testConnectEmitsConnectingAtAttemptZero() {
        var received: [HotReloadStatus] = []
        HotReloadManager.shared.onStatusChange = { received.append($0) }

        HotReloadManager.shared.connect(to: URL(string: "ws://localhost:8174")!)

        XCTAssertEqual(received, [.connecting(attempt: 0)])
    }

    func testReconnectAttemptsResetOnEachConnectCall() {
        var received: [HotReloadStatus] = []
        HotReloadManager.shared.onStatusChange = { received.append($0) }

        HotReloadManager.shared.connect(to: URL(string: "ws://localhost:8174")!)
        HotReloadManager.shared.connect(to: URL(string: "ws://localhost:8175")!)

        // Every fresh connect() call restarts the attempt counter at 0,
        // regardless of how many prior connects/reconnects happened.
        XCTAssertEqual(received, [.connecting(attempt: 0), .connecting(attempt: 0)])
    }

    func testHotReloadStatusEquatable() {
        XCTAssertEqual(HotReloadStatus.connecting(attempt: 1), HotReloadStatus.connecting(attempt: 1))
        XCTAssertNotEqual(HotReloadStatus.connecting(attempt: 1), HotReloadStatus.connecting(attempt: 2))
        XCTAssertNotEqual(HotReloadStatus.connecting(attempt: 0), HotReloadStatus.connected)
        XCTAssertEqual(HotReloadStatus.connected, HotReloadStatus.connected)
    }
}
#endif
