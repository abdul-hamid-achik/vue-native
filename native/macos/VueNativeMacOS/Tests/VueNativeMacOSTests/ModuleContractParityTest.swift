import XCTest
import AppKit
import VueNativeShared
@testable import VueNativeMacOS

/// Cross-platform module contract parity checks for macOS.
///
/// Mirrors the Android `ModuleContractParityTest`: for a representative set of
/// modules we construct the module directly, invoke a documented method, and
/// assert that the call is *recognized* (no "Unknown method" error) and that the
/// result has the documented shape. Kept deliberately bounded and hardware-free
/// so it runs deterministically in CI (no camera, biometrics, geolocation, OTA).
@MainActor
final class ModuleContractParityTest: XCTestCase {

    override func setUp() {
        super.setUp()
        // Several macOS modules (DeviceInfo, Window, Menu) dereference the
        // implicitly-unwrapped `NSApp` global. In a real app the shared
        // application always exists before any module runs; in an isolated test
        // run it may not, which would crash those modules. Initialize it here so
        // the tests are deterministic and independent of execution order.
        _ = NSApplication.shared
    }

    // MARK: - Helpers

    private final class InvokeResult {
        var result: Any?
        var error: String? = "not_called"
    }

    private final class MockEventDispatcher: NativeEventDispatcher {
        func dispatchGlobalEvent(_ eventName: String, payload: [String: Any]) {}
    }

    /// Invoke a module method and wait for its async callback. Modules dispatch
    /// onto the main queue (or a global queue for FileSystem); awaiting
    /// fulfillment pumps the run loop so those blocks execute without deadlock.
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

    // MARK: - Clipboard

    func testClipboardSupportsCopyAndPasteRoundtrip() async {
        let module = ClipboardModule()
        let text = "Vue Native \(UUID().uuidString)"

        let copy = await invoke(module, method: "copy", args: [text])
        XCTAssertNil(copy.error)

        let paste = await invoke(module, method: "paste", args: [])
        XCTAssertNil(paste.error)
        XCTAssertEqual(paste.result as? String, text)
    }

    func testClipboardRejectsUnknownMethod() async {
        let module = ClipboardModule()
        let result = await invoke(module, method: "definitelyNotAMethod", args: [])
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("Unknown method") == true)
    }

    // MARK: - Haptics (no-op on macOS hardware-less path)

    func testHapticsNotificationFeedbackIsRecognized() async {
        let module = HapticsModule()
        let result = await invoke(module, method: "notificationFeedback", args: ["success"])
        XCTAssertNil(result.error)
    }

    func testHapticsSelectionChangedIsRecognized() async {
        let module = HapticsModule()
        let result = await invoke(module, method: "selectionChanged", args: [])
        XCTAssertNil(result.error)
    }

    // MARK: - DeviceInfo

    func testDeviceInfoReturnsDocumentedShape() async {
        let module = DeviceInfoModule()
        let result = await invoke(module, method: "getInfo", args: [])
        XCTAssertNil(result.error)

        guard let info = result.result as? [String: Any] else {
            return XCTFail("expected a dictionary result from DeviceInfo.getInfo")
        }
        XCTAssertEqual(info["platform"] as? String, "macos")
        XCTAssertEqual(info["systemName"] as? String, "macOS")
        XCTAssertNotNil(info["systemVersion"])
        XCTAssertNotNil(info["locale"])
        XCTAssertNotNil(info["colorScheme"])
        XCTAssertNotNil(info["screenWidth"])
        XCTAssertNotNil(info["screenHeight"])
        XCTAssertNotNil(info["scale"])
    }

    // MARK: - Window (macOS-only)

    func testWindowSetTitleIsRecognizedWithoutMainWindow() async {
        // setTitle uses an optional chain on NSApp.mainWindow, so it succeeds
        // (no error) even when no main window exists in the test host.
        let module = WindowModule()
        let result = await invoke(module, method: "setTitle", args: ["Vue Native Test"])
        XCTAssertNil(result.error)
    }

    func testWindowRejectsUnknownMethod() async {
        let module = WindowModule()
        let result = await invoke(module, method: "definitelyNotAMethod", args: [])
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("Unknown method") == true)
    }

    // MARK: - Menu (macOS-only)

    func testMenuSetAppMenuIsRecognized() async {
        let module = MenuModule(dispatcher: MockEventDispatcher())
        let items: [[String: Any]] = [
            [
                "title": "File",
                "items": [
                    ["title": "New", "id": "new"],
                    ["separator": true],
                    ["title": "Quit", "key": "q", "id": "quit"],
                ],
            ]
        ]
        let result = await invoke(module, method: "setAppMenu", args: [items])
        XCTAssertNil(result.error)
    }

    func testMenuRejectsUnknownMethod() async {
        let module = MenuModule(dispatcher: MockEventDispatcher())
        let result = await invoke(module, method: "definitelyNotAMethod", args: [])
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("Unknown method") == true)
    }

    // MARK: - FileSystem (shared module)

    func testFileSystemWriteAndReadRoundtrip() async {
        let module = FileSystemModule()
        let dir = NSTemporaryDirectory() + "vn-parity-\(UUID().uuidString)"
        let path = dir + "/hello.txt"
        let content = "Vue Native FileSystem"
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let write = await invoke(module, method: "writeFile", args: [path, content])
        XCTAssertNil(write.error)

        let read = await invoke(module, method: "readFile", args: [path])
        XCTAssertNil(read.error)
        XCTAssertEqual(read.result as? String, content)
    }

    func testFileSystemExistsReportsShape() async {
        let module = FileSystemModule()
        let result = await invoke(module, method: "exists", args: ["/definitely/not/here-\(UUID().uuidString)"])
        XCTAssertNil(result.error)
        XCTAssertEqual(result.result as? Bool, false)
    }
}
