#if canImport(UIKit)
import XCTest
@testable import VueNativeCore

@MainActor
final class WebSocketModuleTests: XCTestCase {
    func testWrapperForwardsModuleContract() {
        let module = WebSocketModule(bridge: .shared)
        XCTAssertEqual(module.moduleName, "WebSocket")

        var response: (result: Any?, error: String?)?
        module.invoke(method: "connect", args: []) { result, error in
            response = (result, error)
        }

        XCTAssertNil(response?.result)
        XCTAssertEqual(response?.error, "WebSocketModule: expected (url, connectionId)")
    }

    func testWrapperDestroyIsIdempotentAndPreventsRestart() {
        let module = WebSocketModule(bridge: .shared)

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
#endif
