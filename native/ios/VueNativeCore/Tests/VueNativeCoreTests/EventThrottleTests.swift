#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

@MainActor
final class EventThrottleTests: XCTestCase {

    // MARK: - Initialization

    func testInitializationWithDefaultInterval() {
        let throttle = EventThrottle { _ in }
        XCTAssertEqual(throttle.interval, 0.016, accuracy: 0.001, "Default interval should be ~16ms")
    }

    func testInitializationWithCustomInterval() {
        let throttle = EventThrottle(interval: 0.1) { _ in }
        XCTAssertEqual(throttle.interval, 0.1, accuracy: 0.001, "Custom interval should be 0.1s")
    }

    // MARK: - First Event Fires Immediately

    func testFirstEventFiresImmediately() {
        var firedPayload: Any?
        var fireCount = 0

        let throttle = EventThrottle(interval: 1.0) { payload in
            firedPayload = payload
            fireCount += 1
        }

        throttle.fire("hello")

        XCTAssertEqual(fireCount, 1, "First event should fire immediately")
        XCTAssertEqual(firedPayload as? String, "hello", "Payload should be passed through")
    }

    // MARK: - Events Within Throttle Window Are Suppressed

    func testEventsWithinWindowAreSuppressed() {
        var fireCount = 0

        let throttle = EventThrottle(interval: 10.0) { _ in
            fireCount += 1
        }

        // First fire — immediate
        throttle.fire("first")
        XCTAssertEqual(fireCount, 1, "First event should fire immediately")

        // Rapid fires within the throttle window — should NOT fire immediately
        throttle.fire("second")
        throttle.fire("third")

        // Only the first call fires synchronously; the rest schedule trailing calls
        XCTAssertEqual(fireCount, 1, "Subsequent events within the throttle window should be suppressed synchronously")
    }

    // MARK: - Events After Window Expires Fire

    func testEventsAfterWindowExpireFire() {
        let expectation = self.expectation(description: "Throttled event fires after window")
        var fireCount = 0

        let throttle = EventThrottle(interval: 0.05) { _ in
            fireCount += 1
            if fireCount == 2 {
                expectation.fulfill()
            }
        }

        // First fire — immediate
        throttle.fire("first")
        XCTAssertEqual(fireCount, 1, "First event should fire immediately")

        // Wait for the throttle window to expire, then fire again
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            throttle.fire("second")
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(fireCount, 2, "Event after window expiry should fire")
    }

    // MARK: - Trailing Call Delivers Latest Payload

    func testTrailingCallDeliversLatestPayload() {
        let expectation = self.expectation(description: "Trailing call fires")
        var payloads: [String] = []

        let throttle = EventThrottle(interval: 0.05) { payload in
            if let str = payload as? String {
                payloads.append(str)
            }
            if payloads.count == 2 {
                expectation.fulfill()
            }
        }

        // First fire — immediate
        throttle.fire("first")

        // Rapid fires — only the latest should be delivered as trailing
        throttle.fire("second")
        throttle.fire("third")
        throttle.fire("fourth")

        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(payloads.first, "first", "First payload should be 'first'")
        XCTAssertEqual(payloads.last, "fourth", "Trailing call should deliver the latest payload")
    }

    // MARK: - Multiple Throttle Instances Are Independent

    func testMultipleThrottleInstancesAreIndependent() {
        var countA = 0
        var countB = 0

        let throttleA = EventThrottle(interval: 10.0) { _ in countA += 1 }
        let throttleB = EventThrottle(interval: 10.0) { _ in countB += 1 }

        throttleA.fire(nil)
        throttleB.fire(nil)

        XCTAssertEqual(countA, 1, "Throttle A should fire independently")
        XCTAssertEqual(countB, 1, "Throttle B should fire independently")
    }

    // MARK: - Nil Payload Is Supported

    func testNilPayloadIsSupported() {
        var fired = false

        let throttle = EventThrottle(interval: 0.016) { payload in
            XCTAssertNil(payload, "Nil payload should be passed through")
            fired = true
        }

        throttle.fire(nil)
        XCTAssertTrue(fired, "Handler should fire with nil payload")
    }

    // MARK: - Dictionary Payload Is Supported

    func testDictionaryPayloadIsSupported() {
        var receivedPayload: [String: Any]?

        let throttle = EventThrottle(interval: 0.016) { payload in
            receivedPayload = payload as? [String: Any]
        }

        let payload: [String: Any] = ["x": 10.0, "y": 20.0]
        throttle.fire(payload)

        XCTAssertNotNil(receivedPayload, "Dictionary payload should be received")
        XCTAssertEqual(receivedPayload?["x"] as? Double, 10.0, "x should be 10.0")
        XCTAssertEqual(receivedPayload?["y"] as? Double, 20.0, "y should be 20.0")
    }
}
#endif
