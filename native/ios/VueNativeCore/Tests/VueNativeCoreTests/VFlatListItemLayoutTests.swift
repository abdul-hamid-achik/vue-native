#if canImport(UIKit)
import XCTest
import UIKit
import JavaScriptCore
@testable import VueNativeCore

/// Tests for VFlatList variable-height reporting.
///
/// The runtime renders each variable-height item in a `VView` carrying a
/// `__flatListIndex` prop and an `itemLayout` listener. After every layout pass the
/// bridge must measure each such view and emit `itemLayout` with `{ index, height }`
/// on that node so JS can position items by cumulative measured heights.
///
/// The measurement pass is driven through ``NativeBridge/reportFlatListItemHeights()``
/// — the same code path `triggerLayout()` runs after Yoga resolves frames — because a
/// full laid-out root view hierarchy (window + safe area) cannot be constructed in a
/// unit test. Events are observed by intercepting `__VN_handleEvent` on the shared JS
/// context, the same technique NativeBridgeOperationTests uses for module callbacks.
@MainActor
final class VFlatListItemLayoutTests: XCTestCase {

    /// A single native event observed through the `__VN_handleEvent` interceptor.
    private struct EmittedEvent {
        let nodeId: Int
        let name: String
        let payload: [String: Any]
    }

    private var bridge: NativeBridge!

    override func setUp() {
        super.setUp()
        bridge = NativeBridge.shared
        bridge.reset()
    }

    override func tearDown() {
        uninstallEventInterceptor()
        bridge.reset()
        bridge = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func processOp(_ op: String, args: [Any]) {
        bridge.processOperations([["op": op, "args": args]])
    }

    /// Install a `__VN_handleEvent` interceptor on the shared JS context that forwards
    /// every emitted native event to `handler` on the main actor.
    private func installEventInterceptor(
        _ handler: @escaping (Int, String, [String: Any]) -> Void
    ) async {
        let runtime = JSRuntime.shared
        let initialized = expectation(description: "JavaScript runtime initialized")
        runtime.initialize { initialized.fulfill() }
        await fulfillment(of: [initialized], timeout: 2)

        runtime.jsQueue.sync {
            guard let context = runtime.context else {
                return XCTFail("Expected an initialized JavaScript context")
            }
            let interceptor: @convention(block) (JSValue, JSValue, JSValue) -> Void = { nodeIdValue, eventNameValue, payloadValue in
                let nodeId = Int(nodeIdValue.toInt32())
                let eventName = eventNameValue.toString() ?? ""
                let payload = (payloadValue.toDictionary() as? [String: Any]) ?? [:]
                Task { @MainActor in
                    handler(nodeId, eventName, payload)
                }
            }
            context.setObject(interceptor, forKeyedSubscript: "__VN_handleEvent" as NSString)
        }
    }

    /// Restore the no-op `__VN_handleEvent` stub so the shared singleton context does
    /// not leak a test interceptor into unrelated tests.
    private func uninstallEventInterceptor() {
        let runtime = JSRuntime.shared
        runtime.jsQueue.sync {
            guard let context = runtime.context else { return }
            let noop: @convention(block) (JSValue, JSValue, JSValue) -> Void = { _, _, _ in }
            context.setObject(noop, forKeyedSubscript: "__VN_handleEvent" as NSString)
        }
    }

    /// Yield until `predicate` is true or the timeout elapses. The async sleep lets the
    /// main-actor hop performed by `dispatchEventToJS` run between polls.
    private func waitUntil(_ predicate: () -> Bool, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // MARK: - Emission

    func testItemLayoutEmitsIndexAndMeasuredHeight() async {
        var emitted: [EmittedEvent] = []
        await installEventInterceptor { nodeId, name, payload in
            emitted.append(EmittedEvent(nodeId: nodeId, name: name, payload: payload))
        }

        processOp("create", args: [1, "VView"])
        // Give the item a known measured height (frames are set by Yoga in production).
        bridge.view(forNodeId: 1)?.frame = CGRect(x: 0, y: 0, width: 320, height: 88)
        processOp("updateProp", args: [1, "__flatListIndex", 3])
        processOp("addEventListener", args: [1, "itemLayout"])

        bridge.reportFlatListItemHeights()

        await waitUntil({ emitted.count == 1 })
        XCTAssertEqual(emitted.count, 1, "exactly one itemLayout event should be emitted")
        XCTAssertEqual(emitted.first?.nodeId, 1)
        XCTAssertEqual(emitted.first?.name, "itemLayout")
        let payload = emitted.first?.payload ?? [:]
        XCTAssertEqual((payload["index"] as? NSNumber)?.intValue, 3)
        XCTAssertEqual((payload["height"] as? NSNumber)?.doubleValue ?? 0, 88, accuracy: 0.001)
    }

    func testItemLayoutReEmitsWhenHeightChanges() async {
        var heights: [Double] = []
        await installEventInterceptor { _, _, payload in
            heights.append((payload["height"] as? NSNumber)?.doubleValue ?? -1)
        }

        processOp("create", args: [1, "VView"])
        bridge.view(forNodeId: 1)?.frame = CGRect(x: 0, y: 0, width: 320, height: 60)
        processOp("updateProp", args: [1, "__flatListIndex", 2])
        processOp("addEventListener", args: [1, "itemLayout"])

        bridge.reportFlatListItemHeights()
        await waitUntil({ heights.count == 1 })

        // Content grew — the next layout pass must report the new height.
        bridge.view(forNodeId: 1)?.frame = CGRect(x: 0, y: 0, width: 320, height: 120)
        bridge.reportFlatListItemHeights()
        await waitUntil({ heights.count == 2 })

        XCTAssertEqual(heights, [60, 120])
    }

    // MARK: - Loop safety

    func testItemLayoutDoesNotReEmitUnchangedHeight() async {
        var emitCount = 0
        await installEventInterceptor { _, _, _ in emitCount += 1 }

        processOp("create", args: [1, "VView"])
        bridge.view(forNodeId: 1)?.frame = CGRect(x: 0, y: 0, width: 320, height: 88)
        processOp("updateProp", args: [1, "__flatListIndex", 0])
        processOp("addEventListener", args: [1, "itemLayout"])

        bridge.reportFlatListItemHeights()
        await waitUntil({ emitCount == 1 })
        XCTAssertEqual(emitCount, 1)

        // Second pass with an unchanged height must not re-emit (would loop JS renders).
        bridge.reportFlatListItemHeights()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(emitCount, 1, "unchanged height must not re-emit itemLayout")
    }

    func testItemLayoutIgnoresZeroHeight() async {
        var emitCount = 0
        await installEventInterceptor { _, _, _ in emitCount += 1 }

        processOp("create", args: [1, "VView"])
        // frame.height == 0 (not laid out yet) — must not be reported.
        processOp("updateProp", args: [1, "__flatListIndex", 0])
        processOp("addEventListener", args: [1, "itemLayout"])

        bridge.reportFlatListItemHeights()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(emitCount, 0, "zero/unresolved height must not be reported")
    }

    // MARK: - Listener gating & lifecycle

    func testItemLayoutDefersUntilListenerRegistered() async {
        var emitCount = 0
        await installEventInterceptor { _, _, _ in emitCount += 1 }

        processOp("create", args: [1, "VView"])
        bridge.view(forNodeId: 1)?.frame = CGRect(x: 0, y: 0, width: 320, height: 88)
        processOp("updateProp", args: [1, "__flatListIndex", 0])

        // No listener yet: the measurement must be deferred, not dropped.
        bridge.reportFlatListItemHeights()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(emitCount, 0, "no event before an itemLayout listener is registered")

        processOp("addEventListener", args: [1, "itemLayout"])
        bridge.reportFlatListItemHeights()
        await waitUntil({ emitCount == 1 })
        XCTAssertEqual(emitCount, 1, "measurement must be reported once the listener exists")
    }

    func testItemLayoutStopsAfterNodeRemoved() async {
        var emitCount = 0
        await installEventInterceptor { _, _, _ in emitCount += 1 }

        processOp("create", args: [1, "VView"])
        processOp("create", args: [2, "VView"])
        processOp("appendChild", args: [1, 2])
        bridge.view(forNodeId: 2)?.frame = CGRect(x: 0, y: 0, width: 320, height: 50)
        processOp("updateProp", args: [2, "__flatListIndex", 0])
        processOp("addEventListener", args: [2, "itemLayout"])

        bridge.reportFlatListItemHeights()
        await waitUntil({ emitCount == 1 })

        processOp("removeChild", args: [2])
        bridge.reportFlatListItemHeights()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(emitCount, 1, "removed node must not keep emitting itemLayout")
    }
}
#endif
