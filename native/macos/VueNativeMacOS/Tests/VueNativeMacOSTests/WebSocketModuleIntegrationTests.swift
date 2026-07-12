import XCTest
import VueNativeShared
@testable import VueNativeMacOS

@MainActor
final class WebSocketModuleIntegrationTests: XCTestCase {
    func testMacBridgeUsesSharedWebSocketContract() {
        let module = VueNativeShared.WebSocketModule(eventDispatcher: NativeBridge.shared)
        XCTAssertEqual(module.moduleName, "WebSocket")

        var response: (result: Any?, error: String?)?
        module.invoke(method: "connect", args: []) { result, error in
            response = (result, error)
        }

        XCTAssertNil(response?.result)
        XCTAssertEqual(response?.error, "WebSocketModule: expected (url, connectionId)")
    }

    func testSharedWebSocketTeardownRemainsIdempotentOnMac() {
        let module = VueNativeShared.WebSocketModule(eventDispatcher: NativeBridge.shared)

        module.destroy()
        module.destroy()

        var response: (result: Any?, error: String?)?
        module.invoke(
            method: "connect",
            args: ["wss://example.test", "socket"]
        ) { result, error in
            response = (result, error)
        }

        XCTAssertNil(response?.result)
        XCTAssertEqual(response?.error, "WebSocketModule: module has been destroyed")
    }
}
