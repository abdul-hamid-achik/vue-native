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

    func testConformsToURLSessionWebSocketDelegate() {
        // Assigning to the protocol existential keeps this a compile-time
        // conformance check without an always-true runtime type test.
        let delegate: URLSessionWebSocketDelegate = manager
        XCTAssertTrue((delegate as AnyObject) === manager)
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
}
#endif
