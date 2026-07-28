#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Tests for `AccessibilityModule` (VoiceOver announcements + focus management).
///
/// `UIAccessibility` is not spyable in unit tests, so these assert the module's
/// observable contract: recognized methods complete without error, missing or
/// invalid arguments and unregistered node ids surface errors, and a valid
/// registered view is accepted by `setFocus`. Modeled on `ModuleContractParityTest`
/// (@MainActor + `wait(for:)`) because the module dispatches its callbacks via
/// `DispatchQueue.main.async`, which `wait(for:)` resolves by spinning the run loop.
@MainActor
final class AccessibilityModuleTests: XCTestCase {

    private var bridge: NativeBridge!

    override func setUp() {
        super.setUp()
        bridge = NativeBridge.shared
        bridge.reset()
    }

    override func tearDown() {
        bridge.reset()
        bridge = nil
        super.tearDown()
    }

    // MARK: - Helper

    @discardableResult
    private func invoke(
        _ module: any NativeModule,
        _ method: String,
        args: [Any] = [],
        timeout: TimeInterval = 3
    ) -> (result: Any?, error: String?) {
        let completed = expectation(description: "\(module.moduleName).\(method)")
        var result: Any?
        var error: String?
        module.invoke(method: method, args: args) { value, callbackError in
            result = value
            error = callbackError
            completed.fulfill()
        }
        wait(for: [completed], timeout: timeout)
        return (result, error)
    }

    // MARK: - Module identity

    func testModuleName() {
        let module = AccessibilityModule()
        XCTAssertEqual(module.moduleName, "Accessibility", "AccessibilityModule should be named 'Accessibility'")
    }

    func testInvokeSyncReturnsNil() {
        let module = AccessibilityModule()
        XCTAssertNil(module.invokeSync(method: "announce", args: ["hi"]), "invokeSync should return nil")
    }

    // MARK: - announce

    func testAnnounceCompletesWithoutError() {
        let module = AccessibilityModule()
        let result = invoke(module, "announce", args: ["3 items added to your cart"])
        XCTAssertNil(result.error, "announce must complete without an error")
    }

    func testAnnounceMissingMessageReturnsError() {
        let module = AccessibilityModule()
        let result = invoke(module, "announce", args: [])
        XCTAssertNotNil(result.error, "announce without a message should return an error")
        XCTAssertTrue(result.error?.contains("missing message") == true, "Error should mention the missing message")
    }

    // MARK: - setFocus

    func testSetFocusMissingNodeIdReturnsError() {
        let module = AccessibilityModule()
        let result = invoke(module, "setFocus", args: [])
        XCTAssertNotNil(result.error, "setFocus without a nodeId should return an error")
        XCTAssertTrue(result.error?.contains("missing nodeId") == true, "Error should mention the missing nodeId")
    }

    func testSetFocusUnregisteredNodeIdReturnsError() {
        let module = AccessibilityModule()
        let result = invoke(module, "setFocus", args: [999_999])
        XCTAssertNotNil(result.error, "setFocus for an unregistered nodeId should return an error")
        XCTAssertTrue(result.error?.contains("not found") == true, "Error should indicate the view was not found")
    }

    func testSetFocusRegisteredViewCompletesWithoutError() {
        let nodeId = 7777
        bridge.processOperations([["op": "create", "args": [nodeId, "VView"]]])
        guard bridge.view(forNodeId: nodeId) != nil else {
            return XCTFail("Expected the bridge to register a view for node \(nodeId)")
        }

        let module = AccessibilityModule()
        let result = invoke(module, "setFocus", args: [nodeId])
        XCTAssertNil(result.error, "setFocus on a registered view must complete without an error")
    }

    func testSetFocusCoercesDoubleNodeId() {
        let nodeId = 8888
        bridge.processOperations([["op": "create", "args": [nodeId, "VView"]]])
        guard bridge.view(forNodeId: nodeId) != nil else {
            return XCTFail("Expected the bridge to register a view for node \(nodeId)")
        }

        let module = AccessibilityModule()
        // JS numbers frequently arrive as Double; ensure coercion to Int works.
        let result = invoke(module, "setFocus", args: [Double(nodeId)])
        XCTAssertNil(result.error, "setFocus should coerce a Double nodeId to Int")
    }

    // MARK: - Unknown method

    func testUnknownMethodReturnsError() {
        let module = AccessibilityModule()
        let result = invoke(module, "nonexistent", args: [])
        XCTAssertNotNil(result.error, "Unknown method should return an error")
        XCTAssertTrue(result.error?.contains("Unknown method") == true, "Error should mention 'Unknown method'")
    }
}
#endif
