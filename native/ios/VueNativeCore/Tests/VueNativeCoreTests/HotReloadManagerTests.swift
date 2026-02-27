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
        // Verify HotReloadManager conforms to the delegate protocol
        XCTAssertTrue(manager is URLSessionWebSocketDelegate,
                      "HotReloadManager should conform to URLSessionWebSocketDelegate")
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
}
#endif
