import XCTest
import AppKit
import VueNativeShared
@testable import VueNativeMacOS

/// Tests for `AccessibilityModule` (VoiceOver announcements + focus management).
///
/// The module posts NSAccessibility notifications on the main queue; the async
/// helper below awaits the callback while pumping the run loop so those blocks
/// execute without deadlock. Everything is hardware-free and deterministic so it
/// runs cleanly in CI (VoiceOver need not be running).
@MainActor
final class AccessibilityModuleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // announce() posts against NSApplication.shared; make sure the shared
        // application exists so the test is deterministic regardless of order.
        _ = NSApplication.shared
    }

    // MARK: - Helpers

    private final class InvokeResult {
        var result: Any?
        var error: String? = "not_called"
    }

    private func invoke(
        _ module: NativeModule,
        method: String,
        args: [Any],
        timeout: TimeInterval = 3
    ) async -> InvokeResult {
        let box = InvokeResult()
        let exp = expectation(description: "\(module.moduleName).\(method)")
        module.invoke(method: method, args: args) { result, error in
            box.result = result
            box.error = error
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: timeout)
        return box
    }

    /// Build a module whose viewLookup returns `view` for `knownId` and nil otherwise.
    private func makeModule(knownId: Int = 42, view: NSView? = NSView()) -> AccessibilityModule {
        AccessibilityModule(viewLookup: { nodeId in
            nodeId == knownId ? view : nil
        })
    }

    // MARK: - announce

    func testAnnounceCompletesWithoutError() async {
        let module = makeModule()
        let result = await invoke(module, method: "announce", args: ["3 items added to your cart"])
        XCTAssertNil(result.error)
    }

    func testAnnounceWithoutMessageReturnsError() async {
        let module = makeModule()
        let result = await invoke(module, method: "announce", args: [])
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("missing message") == true)
    }

    // MARK: - setFocus

    func testSetFocusWithInvalidNodeIdReturnsError() async {
        let module = makeModule()
        // A non-numeric argument cannot be coerced to a node id.
        let result = await invoke(module, method: "setFocus", args: ["not-a-number"])
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("invalid node id") == true)
    }

    func testSetFocusWithUnknownNodeIdReturnsError() async {
        let module = makeModule(knownId: 42)
        // 999 is not present in the view registry.
        let result = await invoke(module, method: "setFocus", args: [999])
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("not found") == true)
    }

    func testSetFocusWithValidNodeIdDoesNotCrash() async {
        let module = makeModule(knownId: 42, view: NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10)))
        let result = await invoke(module, method: "setFocus", args: [42])
        XCTAssertNil(result.error)
    }

    func testSetFocusAcceptsDoubleNodeId() async {
        // JavaScriptCore frequently bridges numbers as Double.
        let module = makeModule(knownId: 7, view: NSView())
        let result = await invoke(module, method: "setFocus", args: [7.0])
        XCTAssertNil(result.error)
    }

    // MARK: - unknown method

    func testRejectsUnknownMethod() async {
        let module = makeModule()
        let result = await invoke(module, method: "definitelyNotAMethod", args: [])
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("Unknown method") == true)
    }
}
