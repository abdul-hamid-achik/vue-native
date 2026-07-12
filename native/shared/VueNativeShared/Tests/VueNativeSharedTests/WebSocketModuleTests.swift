import Foundation
import XCTest
@testable import VueNativeShared

final class WebSocketModuleTests: XCTestCase {
    func testOpenIsHandshakeDrivenAndCurrentMessagesAreDelivered() {
        let harness = Harness()
        let response = harness.connect(id: "socket")

        XCTAssertEqual(response.result as? Bool, true)
        XCTAssertNil(response.error)
        XCTAssertEqual(harness.transports.count, 1)
        XCTAssertEqual(harness.transports[0].startCount, 1)
        XCTAssertTrue(harness.dispatcher.events.isEmpty)

        harness.transports[0].fireOpen()
        harness.transports[0].fireMessage("hello")
        drainMainQueue()

        XCTAssertEqual(harness.dispatcher.events.map(\.name), ["websocket:open", "websocket:message"])
        XCTAssertEqual(harness.dispatcher.events.last?.payload["data"] as? String, "hello")
    }

    func testSameIdReplacementSuppressesEveryStaleCallback() {
        let harness = Harness()
        _ = harness.connect(id: "socket")
        let first = harness.transports[0]
        _ = harness.connect(id: "socket")
        let second = harness.transports[1]

        XCTAssertEqual(first.cancelCount, 1)

        first.fireOpen()
        first.fireMessage("stale")
        first.fireFailure(TestError.stale)
        first.fireClose(code: 1006, reason: "stale")
        second.fireOpen()
        second.fireMessage("current")
        drainMainQueue()

        XCTAssertEqual(harness.dispatcher.events.map(\.name), ["websocket:open", "websocket:message"])
        XCTAssertEqual(harness.dispatcher.events.last?.payload["data"] as? String, "current")
        XCTAssertEqual(harness.module.activeConnectionCount, 1)
    }

    func testExplicitCloseOwnsOneTerminalEvent() {
        let harness = Harness()
        _ = harness.connect(id: "socket")
        let transport = harness.transports[0]
        transport.fireOpen()
        drainMainQueue()
        harness.dispatcher.removeAllEvents()

        let response = harness.invoke("close", args: ["socket", 1000, "done"])
        transport.fireClose(code: 1000, reason: "done")
        transport.fireFailure(TestError.stale)
        drainMainQueue()

        XCTAssertEqual(response.result as? Bool, true)
        XCTAssertNil(response.error)
        XCTAssertEqual(transport.closeCalls.count, 1)
        XCTAssertEqual(harness.dispatcher.events.map(\.name), ["websocket:close"])
        XCTAssertEqual(harness.dispatcher.events[0].payload["code"] as? Int, 1000)
        XCTAssertEqual(harness.dispatcher.events[0].payload["reason"] as? String, "done")
        XCTAssertEqual(harness.module.activeConnectionCount, 0)
    }

    func testFailureEmitsErrorAndCloseOnce() {
        let harness = Harness()
        _ = harness.connect(id: "socket")
        let transport = harness.transports[0]

        transport.fireFailure(TestError.failed)
        transport.fireFailure(TestError.stale)
        transport.fireClose(code: 1006, reason: "duplicate")
        drainMainQueue()

        XCTAssertEqual(harness.dispatcher.events.map(\.name), ["websocket:error", "websocket:close"])
        XCTAssertEqual(harness.dispatcher.events[1].payload["code"] as? Int, 1006)
        XCTAssertEqual(harness.module.activeConnectionCount, 0)
    }

    func testAcceptedOpenAndMessageStayOrderedBeforeTerminalEvent() {
        let harness = Harness()
        _ = harness.connect(id: "socket")
        let transport = harness.transports[0]

        transport.fireOpen()
        transport.fireMessage("last message")
        transport.fireClose(code: 1000, reason: "done")
        drainMainQueue()

        XCTAssertEqual(
            harness.dispatcher.events.map(\.name),
            ["websocket:open", "websocket:message", "websocket:close"]
        )
        XCTAssertEqual(harness.dispatcher.events[1].payload["data"] as? String, "last message")
    }

    func testConcurrentTerminalCannotOvertakeAcceptedMessage() {
        let barrier = AcceptanceBarrier()
        let harness = Harness(eventAcceptanceHook: barrier.waitIfEnabled)
        _ = harness.connect(id: "socket")
        let transport = harness.transports[0]
        transport.fireOpen()
        drainMainQueue()
        harness.dispatcher.removeAllEvents()

        barrier.enable()
        let callbacks = DispatchGroup()
        callbacks.enter()
        DispatchQueue.global().async {
            transport.fireMessage("accepted")
            callbacks.leave()
        }
        XCTAssertEqual(barrier.accepted.wait(timeout: .now() + 1), .success)

        let terminalAttempted = DispatchSemaphore(value: 0)
        callbacks.enter()
        DispatchQueue.global().async {
            terminalAttempted.signal()
            transport.fireClose(code: 1000, reason: "done")
            callbacks.leave()
        }
        XCTAssertEqual(terminalAttempted.wait(timeout: .now() + 1), .success)

        barrier.release.signal()
        XCTAssertEqual(callbacks.wait(timeout: .now() + 1), .success)
        drainMainQueue()

        XCTAssertEqual(harness.dispatcher.events.map(\.name), ["websocket:message", "websocket:close"])
        XCTAssertEqual(harness.dispatcher.events[0].payload["data"] as? String, "accepted")
    }

    func testDestroyIsIdempotentAndSuppressesQueuedAndLateEvents() {
        let harness = Harness()
        _ = harness.connect(id: "socket")
        let transport = harness.transports[0]
        transport.fireOpen()

        harness.module.destroy()
        harness.module.destroy()
        transport.fireMessage("late")
        transport.fireFailure(TestError.stale)
        transport.fireClose(code: 1001, reason: "late")
        drainMainQueue()

        XCTAssertEqual(transport.cancelCount, 1)
        XCTAssertTrue(harness.dispatcher.events.isEmpty)
        XCTAssertEqual(harness.module.activeConnectionCount, 0)

        let response = harness.connect(id: "replacement")
        XCTAssertNil(response.result)
        XCTAssertEqual(response.error, "WebSocketModule: module has been destroyed")
        XCTAssertEqual(harness.transports.count, 2)
        XCTAssertEqual(harness.transports[1].cancelCount, 1)
        XCTAssertEqual(harness.transports[1].startCount, 0)
    }

    private func drainMainQueue() {
        let expectation = expectation(description: "main queue drained")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1)
    }
}

private extension WebSocketModuleTests {
    final class Harness {
        let dispatcher = RecordingDispatcher()
        let factory: FakeTransportFactory
        let module: WebSocketModule

        var transports: [FakeWebSocketTransport] { factory.transports }

        init(eventAcceptanceHook: (() -> Void)? = nil) {
            let factory = FakeTransportFactory()
            self.factory = factory
            module = WebSocketModule(
                eventDispatcher: dispatcher,
                transportFactory: { _ in factory.makeTransport() },
                eventAcceptanceHook: eventAcceptanceHook
            )
        }

        func connect(id: String) -> (result: Any?, error: String?) {
            invoke("connect", args: ["wss://example.test", id])
        }

        func invoke(_ method: String, args: [Any]) -> (result: Any?, error: String?) {
            var response: (result: Any?, error: String?)?
            module.invoke(method: method, args: args) { result, error in
                response = (result, error)
            }
            return response ?? (nil, "callback not invoked")
        }
    }

    final class AcceptanceBarrier {
        let accepted = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private var enabled = false

        func enable() {
            lock.lock()
            enabled = true
            lock.unlock()
        }

        func waitIfEnabled() {
            lock.lock()
            let shouldWait = enabled
            lock.unlock()
            guard shouldWait else { return }
            accepted.signal()
            _ = release.wait(timeout: .now() + 1)
        }
    }

    final class FakeTransportFactory {
        private(set) var transports: [FakeWebSocketTransport] = []

        func makeTransport() -> FakeWebSocketTransport {
            let transport = FakeWebSocketTransport()
            transports.append(transport)
            return transport
        }
    }

    final class RecordingDispatcher: NativeEventDispatcher {
        private let lock = NSLock()
        private var recordedEvents: [(name: String, payload: [String: Any])] = []

        var events: [(name: String, payload: [String: Any])] {
            lock.lock()
            defer { lock.unlock() }
            return recordedEvents
        }

        func dispatchGlobalEvent(_ eventName: String, payload: [String: Any]) {
            lock.lock()
            recordedEvents.append((eventName, payload))
            lock.unlock()
        }

        func removeAllEvents() {
            lock.lock()
            recordedEvents.removeAll()
            lock.unlock()
        }
    }

    final class FakeWebSocketTransport: WebSocketTransport {
        var onOpen: (() -> Void)?
        var onMessage: ((String) -> Void)?
        var onClose: ((Int, String) -> Void)?
        var onFailure: ((Error) -> Void)?

        var startCount = 0
        var cancelCount = 0
        var sentMessages: [String] = []
        var closeCalls: [(code: Int, reason: String?)] = []

        func start() {
            startCount += 1
        }

        func send(_ data: String, completion: @escaping (Error?) -> Void) {
            sentMessages.append(data)
            completion(nil)
        }

        func close(code: Int, reason: String?) {
            closeCalls.append((code, reason))
        }

        func cancel() {
            cancelCount += 1
        }

        func fireOpen() {
            onOpen?()
        }

        func fireMessage(_ data: String) {
            onMessage?(data)
        }

        func fireClose(code: Int, reason: String) {
            onClose?(code, reason)
        }

        func fireFailure(_ error: Error) {
            onFailure?(error)
        }
    }

    enum TestError: LocalizedError {
        case failed
        case stale

        var errorDescription: String? {
            switch self {
            case .failed:
                return "connection failed"
            case .stale:
                return "stale callback"
            }
        }
    }
}
