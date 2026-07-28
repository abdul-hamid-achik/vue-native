#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Cross-platform module-contract parity tests for iOS.
///
/// Mirrors `native/android/.../ModuleContractParityTest.kt`: for a set of
/// representative modules, invoke a method through the module's public
/// `invoke` API and assert that (a) it is recognized (no "Unknown method"
/// error) and (b) the result has the documented shape. Kept hardware-free so it
/// runs deterministically on the simulator.
@MainActor
final class ModuleContractParityTest: XCTestCase {

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

    /// Invoke a module method and wait for its (async) callback. All iOS modules
    /// dispatch their callbacks onto the main queue, so spinning the run loop via
    /// `wait(for:)` resolves them.
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

    // MARK: - Clipboard
    //
    // Intentionally NOT covered here. `ClipboardModule` routes through
    // `UIPasteboard.general`, whose synchronous cross-process IPC can block the
    // main thread indefinitely in a headless simulator test session (the run
    // hangs past `wait(for:)`'s timeout because the blocked main thread cannot
    // fire the timeout timer). The Android parity test sidesteps this with a
    // Robolectric pasteboard shadow; iOS has no equivalent, so clipboard parity
    // is left to the device/app-shell smoke test rather than risking a hung CI
    // run. The remaining modules below are hardware- and service-free.

    // MARK: - Haptics

    func testHapticsSupportsRuntimeNotificationFeedbackMethod() {
        let module = HapticsModule()
        let result = invoke(module, "notificationFeedback", args: ["success"])
        XCTAssertNil(result.error, "notificationFeedback must be a recognized method (no hardware required)")
    }

    // MARK: - Keyboard

    func testKeyboardGetHeightReturnsDocumentedObjectShape() {
        let module = KeyboardModule()
        let result = invoke(module, "getHeight")

        XCTAssertNil(result.error, "getHeight must be a recognized method")
        let metrics = result.result as? [String: Any]
        XCTAssertNotNil(metrics, "getHeight should return a dictionary")
        XCTAssertEqual(metrics?["height"] as? Double, 0.0)
        XCTAssertEqual(metrics?["isVisible"] as? Bool, false)
    }

    // MARK: - Geolocation

    func testGeolocationRecognizesWatchAndClearWatchMethods() {
        let module = GeolocationModule(bridge: bridge)

        // Without location permission the watch id is a sentinel (-1) but the
        // method itself is recognized (no "Unknown method" error).
        let watch = invoke(module, "watchPosition")
        XCTAssertNil(watch.error, "watchPosition must be a recognized method")
        XCTAssertNotNil(watch.result as? Int, "watchPosition should return an Int watch id")

        let clear = invoke(module, "clearWatch", args: [1])
        XCTAssertNil(clear.error, "clearWatch must be a recognized method")

        module.destroy()
    }

    // MARK: - Animation

    func testAnimationMeasuresRuntimeViewFrame() {
        let nodeId = 4242
        bridge.processOperations([["op": "create", "args": [nodeId, "VView"]]])
        guard let view = bridge.view(forNodeId: nodeId) else {
            return XCTFail("Expected the bridge to register a view for node \(nodeId)")
        }
        // Attach to a window so `convert(_:to: window)` inside measureView is
        // well-defined (a detached view has no window coordinate space).
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(view)
        view.frame = CGRect(x: 0, y: 0, width: 120, height: 80)

        let module = AnimationModule()
        let result = invoke(module, "measureView", args: [nodeId])

        XCTAssertNil(result.error, "measureView must be a recognized method")
        let frame = result.result as? [String: Any]
        XCTAssertNotNil(frame, "measureView should return a frame dictionary")
        XCTAssertEqual(frame?["width"] as? CGFloat, 120)
        XCTAssertEqual(frame?["height"] as? CGFloat, 80)
    }
}
#endif
