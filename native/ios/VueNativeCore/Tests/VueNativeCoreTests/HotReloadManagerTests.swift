#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

@MainActor
final class HotReloadManagerTests: XCTestCase {

    // MARK: - Properties

    private var manager: HotReloadManager!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        manager = HotReloadManager.shared
    }

    override func tearDown() {
        manager.disconnect()
        manager.onStatusChange = nil
        manager = nil
        super.tearDown()
    }

    // MARK: - Singleton Tests

    func testSharedInstanceIsSingleton() {
        let instance1 = HotReloadManager.shared
        let instance2 = HotReloadManager.shared
        XCTAssertTrue(instance1 === instance2, "HotReloadManager.shared should always return the same instance")
    }

    // MARK: - Initialization Tests

    func testInitializationWithURL() {
        let url = URL(string: "ws://localhost:8174")!
        // connect should not crash
        manager.connect(to: url)
        // Just verify it doesn't crash — we can't easily test the WebSocket connection
    }

    // MARK: - Disconnect Tests

    func testDisconnectDoesNotCrash() {
        // Disconnect without connecting first — should be safe
        manager.disconnect()
    }

    func testDisconnectAfterConnectDoesNotCrash() {
        let url = URL(string: "ws://localhost:9999")!
        manager.connect(to: url)
        manager.disconnect()
        // Should not crash
    }

    // MARK: - Multiple Connect Calls

    func testMultipleConnectCallsDoNotCrash() {
        let url1 = URL(string: "ws://localhost:8174")!
        let url2 = URL(string: "ws://localhost:8175")!

        manager.connect(to: url1)
        manager.connect(to: url2)
        manager.disconnect()
    }

    // MARK: - URLSessionWebSocketDelegate Conformance

    /// The conformance itself is enforced at compile time by passing `manager`
    /// where the delegate is expected; an `XCTAssertTrue(manager is
    /// URLSessionWebSocketDelegate)` would be an always-true runtime type test
    /// that proves nothing. What IS worth asserting is the behaviour the
    /// delegate contract drives: a closed socket must schedule a reconnect and
    /// report it through `onStatusChange`, because a hot-reload client that
    /// silently stops after one disconnect looks identical to a working one
    /// until the next edit.
    func testSocketCloseSchedulesReconnectAndReportsConnectingStatus() {
        var statuses: [HotReloadStatus] = []
        manager.onStatusChange = { status in statuses.append(status) }

        // scheduleReconnect() guards on a known server URL, so the manager must
        // have been pointed at one — exactly the state a live session is in
        // when its socket drops. Nothing is listening on this port; the
        // connect attempt failing is irrelevant to what is under test.
        manager.connect(to: URL(string: "ws://localhost:8174")!)
        statuses.removeAll()

        let task = URLSession.shared.webSocketTask(with: URL(string: "ws://localhost:8174")!)
        manager.urlSession(
            URLSession.shared,
            webSocketTask: task,
            didCloseWith: .goingAway,
            reason: nil,
        )

        XCTAssertTrue(
            statuses.contains(where: { status in
                if case .connecting = status { return true }
                return false
            }),
            "A closed socket must report a reconnect attempt, got \(statuses)",
        )

        manager.disconnect()
    }

    // MARK: - Connect/Disconnect Cycle

    func testConnectDisconnectCycleDoesNotCrash() {
        let url = URL(string: "ws://localhost:8174")!

        for _ in 0..<5 {
            manager.connect(to: url)
            manager.disconnect()
        }
        // Multiple cycles should not crash
    }

    // MARK: - Reconnect Backoff

    func testReconnectDelayUsesExponentialBackoff() {
        // 1s, 2s, 4s, 8s, 16s ... doubling per attempt.
        XCTAssertEqual(manager.reconnectDelay(forAttempt: 1), 1.0)
        XCTAssertEqual(manager.reconnectDelay(forAttempt: 2), 2.0)
        XCTAssertEqual(manager.reconnectDelay(forAttempt: 3), 4.0)
        XCTAssertEqual(manager.reconnectDelay(forAttempt: 4), 8.0)
        XCTAssertEqual(manager.reconnectDelay(forAttempt: 5), 16.0)
    }

    func testReconnectDelayIsCappedAt30Seconds() {
        // 2^5 = 32s would exceed the cap, so attempt 6 onwards stays at 30s.
        XCTAssertEqual(manager.reconnectDelay(forAttempt: 6), 30.0)
        XCTAssertEqual(manager.reconnectDelay(forAttempt: 7), 30.0)
        XCTAssertEqual(manager.reconnectDelay(forAttempt: 20), 30.0)
    }

    func testReconnectDelayNeverGivesUp() {
        // Far beyond the old hard limit of 10 attempts, the delay must remain
        // finite and positive — reconnection is never abandoned while a server
        // URL is configured.
        for attempt in [10, 11, 50, 100, 1000, 10_000] {
            let delay = manager.reconnectDelay(forAttempt: attempt)
            XCTAssertTrue(delay.isFinite, "delay for attempt \(attempt) should be finite")
            XCTAssertGreaterThan(delay, 0, "delay for attempt \(attempt) should stay positive")
            XCTAssertLessThanOrEqual(delay, 30.0, "delay for attempt \(attempt) should respect the cap")
        }
    }

    func testReconnectDelayHandlesNonPositiveAttempts() {
        // Guard against accidental zero/negative attempt counts: clamp to the
        // base delay rather than crashing or producing a nonsensical value.
        XCTAssertEqual(manager.reconnectDelay(forAttempt: 0), 1.0)
        XCTAssertEqual(manager.reconnectDelay(forAttempt: -3), 1.0)
    }

    // MARK: - Status callback

    /// `connect(to:)` emits `.connecting(attempt: 0)` synchronously, before
    /// any network activity is scheduled, so this is deterministic without a
    /// real dev server. Reconnect/connected transitions depend on real
    /// socket activity and are covered by the `HotReloadStatus` enum mapping
    /// tests instead (`HotReloadStatusViewTests`).
    func testConnectEmitsConnectingAtAttemptZero() {
        var received: [HotReloadStatus] = []
        manager.onStatusChange = { received.append($0) }

        manager.connect(to: URL(string: "ws://localhost:8174")!)

        XCTAssertEqual(received, [.connecting(attempt: 0)])
    }

    func testReconnectAttemptsResetOnEachConnectCall() {
        var received: [HotReloadStatus] = []
        manager.onStatusChange = { received.append($0) }

        manager.connect(to: URL(string: "ws://localhost:8174")!)
        manager.connect(to: URL(string: "ws://localhost:8175")!)

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
