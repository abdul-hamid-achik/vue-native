#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

// NOTE: Not @MainActor — native modules dispatch callbacks via
// DispatchQueue.main.async which deadlocks with @MainActor + waitForExpectations.
final class NativeModuleTests: XCTestCase {

    // MARK: - HapticsModule Tests

    func testHapticsModuleName() {
        let module = HapticsModule()
        XCTAssertEqual(module.moduleName, "Haptics", "HapticsModule should be named 'Haptics'")
    }

    func testHapticsModuleVibrateDoesNotCrash() {
        let module = HapticsModule()
        let expectation = self.expectation(description: "vibrate callback")

        module.invoke(method: "vibrate", args: ["medium"]) { result, error in
            XCTAssertNil(error, "vibrate should not return an error")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testHapticsModuleVibrateStyles() {
        let module = HapticsModule()
        let styles = ["light", "medium", "heavy", "rigid", "soft"]

        for style in styles {
            let expectation = self.expectation(description: "vibrate \(style)")
            module.invoke(method: "vibrate", args: [style]) { _, error in
                XCTAssertNil(error, "vibrate(\(style)) should not return an error")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    func testHapticsModuleNotificationFeedback() {
        let module = HapticsModule()
        let types = ["success", "warning", "error"]

        for type in types {
            let expectation = self.expectation(description: "notificationFeedback \(type)")
            module.invoke(method: "notificationFeedback", args: [type]) { _, error in
                XCTAssertNil(error, "notificationFeedback(\(type)) should not return an error")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    func testHapticsModuleSelectionChanged() {
        let module = HapticsModule()
        let expectation = self.expectation(description: "selectionChanged callback")

        module.invoke(method: "selectionChanged", args: []) { _, error in
            XCTAssertNil(error, "selectionChanged should not return an error")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testHapticsModuleUnknownMethodReturnsError() {
        let module = HapticsModule()
        let expectation = self.expectation(description: "unknown method callback")

        module.invoke(method: "nonexistent", args: []) { _, error in
            XCTAssertNotNil(error, "Unknown method should return an error")
            XCTAssertTrue(error!.contains("Unknown method"), "Error should mention 'Unknown method'")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - ClipboardModule Tests

    func testClipboardModuleName() {
        let module = ClipboardModule()
        XCTAssertEqual(module.moduleName, "Clipboard", "ClipboardModule should be named 'Clipboard'")
    }

    func testClipboardModuleCopy() {
        let module = ClipboardModule()
        let expectation = self.expectation(description: "copy callback")

        module.invoke(method: "copy", args: ["test clipboard"]) { _, copyError in
            XCTAssertNil(copyError, "copy should not return an error")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    // NOTE: Clipboard paste test omitted — UIPasteboard.general.string (read)
    // triggers iOS clipboard access permission dialog in the simulator,
    // which blocks the test runner indefinitely.

    func testClipboardModuleCopyMissingTextReturnsError() {
        let module = ClipboardModule()
        let expectation = self.expectation(description: "copy without text")

        module.invoke(method: "copy", args: []) { _, error in
            XCTAssertNotNil(error, "copy without text should return an error")
            XCTAssertTrue(error!.contains("missing text"), "Error should indicate missing text")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testClipboardModuleUnknownMethod() {
        let module = ClipboardModule()
        let expectation = self.expectation(description: "unknown method")

        module.invoke(method: "nonexistent", args: []) { _, error in
            XCTAssertNotNil(error, "Unknown method should return an error")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - DeviceInfoModule Tests

    func testDeviceInfoModuleName() {
        let module = DeviceInfoModule()
        XCTAssertEqual(module.moduleName, "DeviceInfo", "DeviceInfoModule should be named 'DeviceInfo'")
    }

    func testDeviceInfoModuleGetInfoReturnsDeviceData() {
        let module = DeviceInfoModule()
        let expectation = self.expectation(description: "getInfo callback")

        module.invoke(method: "getInfo", args: []) { result, error in
            XCTAssertNil(error, "getInfo should not return an error")
            XCTAssertNotNil(result, "getInfo should return device info")

            if let info = result as? [String: Any] {
                XCTAssertNotNil(info["model"], "Should include model")
                XCTAssertNotNil(info["systemVersion"], "Should include systemVersion")
                XCTAssertNotNil(info["systemName"], "Should include systemName")
                XCTAssertNotNil(info["screenWidth"], "Should include screenWidth")
                XCTAssertNotNil(info["screenHeight"], "Should include screenHeight")
                XCTAssertNotNil(info["scale"], "Should include scale")

                // Verify screen dimensions are positive
                let width = info["screenWidth"] as? CGFloat ?? 0
                XCTAssertGreaterThan(width, 0, "screenWidth should be positive")
                let height = info["screenHeight"] as? CGFloat ?? 0
                XCTAssertGreaterThan(height, 0, "screenHeight should be positive")
                let scale = info["scale"] as? CGFloat ?? 0
                XCTAssertGreaterThan(scale, 0, "scale should be positive")
            } else {
                XCTFail("getInfo result should be a [String: Any] dictionary")
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testDeviceInfoModuleUnknownMethod() {
        let module = DeviceInfoModule()
        let expectation = self.expectation(description: "unknown method")

        module.invoke(method: "nonexistent", args: []) { _, error in
            XCTAssertNotNil(error, "Unknown method should return an error")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - AsyncStorageModule Tests

    func testAsyncStorageModuleName() {
        let module = AsyncStorageModule()
        XCTAssertEqual(module.moduleName, "AsyncStorage", "AsyncStorageModule should be named 'AsyncStorage'")
    }

    func testAsyncStorageSetAndGetItem() {
        let module = AsyncStorageModule()
        let testKey = "test_key_\(UUID().uuidString)"

        // AsyncStorageModule dispatches to DispatchQueue.global, so we can
        // chain set → get → remove within a single expectation to avoid
        // multiple sequential waitForExpectations on @MainActor.
        let expectation = self.expectation(description: "set, get, and remove")

        module.invoke(method: "setItem", args: [testKey, "test_value"]) { _, setError in
            XCTAssertNil(setError, "setItem should not return an error")

            module.invoke(method: "getItem", args: [testKey]) { result, getError in
                XCTAssertNil(getError, "getItem should not return an error")
                XCTAssertEqual(result as? String, "test_value", "getItem should return the stored value")

                // Clean up
                module.invoke(method: "removeItem", args: [testKey]) { _, _ in
                    expectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    func testAsyncStorageRemoveItem() {
        let module = AsyncStorageModule()
        let testKey = "remove_test_\(UUID().uuidString)"
        let expectation = self.expectation(description: "set, remove, verify")

        // Chain: set → remove → get (verify nil) in one expectation
        module.invoke(method: "setItem", args: [testKey, "to_remove"]) { _, _ in
            module.invoke(method: "removeItem", args: [testKey]) { _, removeError in
                XCTAssertNil(removeError, "removeItem should not return an error")

                module.invoke(method: "getItem", args: [testKey]) { result, getError in
                    XCTAssertNil(getError, "getItem should not return an error")
                    XCTAssertNil(result, "getItem should return nil after removal")
                    expectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    func testAsyncStorageGetItemMissingKeyReturnsError() {
        let module = AsyncStorageModule()
        let expectation = self.expectation(description: "getItem missing key")

        module.invoke(method: "getItem", args: []) { _, error in
            XCTAssertNotNil(error, "getItem without key should return an error")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testAsyncStorageSetItemMissingArgsReturnsError() {
        let module = AsyncStorageModule()
        let expectation = self.expectation(description: "setItem missing args")

        module.invoke(method: "setItem", args: ["keyOnly"]) { _, error in
            XCTAssertNotNil(error, "setItem with missing value should return an error")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testAsyncStorageUnknownMethod() {
        let module = AsyncStorageModule()
        let expectation = self.expectation(description: "unknown method")

        module.invoke(method: "nonexistent", args: []) { _, error in
            XCTAssertNotNil(error, "Unknown method should return an error")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - AnimationModule Tests

    func testAnimationModuleName() {
        let module = AnimationModule()
        XCTAssertEqual(module.moduleName, "Animation", "AnimationModule should be named 'Animation'")
    }

    func testAnimationModuleInvokeSyncReturnsNil() {
        let module = AnimationModule()
        let result = module.invokeSync(method: "timing", args: [])
        XCTAssertNil(result, "invokeSync should return nil for AnimationModule")
    }

    func testAnimationModuleUnknownMethodReturnsError() {
        let module = AnimationModule()
        let expectation = self.expectation(description: "unknown method")

        module.invoke(method: "nonexistent", args: []) { _, error in
            XCTAssertNotNil(error, "Unknown method should return an error")
            XCTAssertTrue(error!.contains("unknown method"), "Error should mention unknown method")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - NetworkModule Tests

    func testNetworkModuleName() {
        let module = NetworkModule(bridge: NativeBridge.shared)
        XCTAssertEqual(module.moduleName, "Network", "NetworkModule should be named 'Network'")
    }

    func testNetworkModuleGetStatusReturnsInfo() {
        let module = NetworkModule(bridge: NativeBridge.shared)
        let expectation = self.expectation(description: "getStatus callback")

        module.invoke(method: "getStatus", args: []) { result, error in
            XCTAssertNil(error, "getStatus should not return an error")
            XCTAssertNotNil(result, "getStatus should return connection info")

            if let info = result as? [String: Any] {
                XCTAssertNotNil(info["isConnected"], "Should include isConnected")
                XCTAssertNotNil(info["connectionType"], "Should include connectionType")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testNetworkModuleUnknownMethod() {
        let module = NetworkModule(bridge: NativeBridge.shared)
        let expectation = self.expectation(description: "unknown method")

        module.invoke(method: "nonexistent", args: []) { _, error in
            XCTAssertNotNil(error, "Unknown method should return an error")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testNetworkModuleInvokeSyncReturnsNil() {
        let module = NetworkModule(bridge: NativeBridge.shared)
        let result = module.invokeSync(method: "getStatus", args: [])
        XCTAssertNil(result, "invokeSync should return nil")
    }

    // MARK: - KeyboardModule Tests

    func testKeyboardModuleName() {
        let module = KeyboardModule()
        XCTAssertEqual(module.moduleName, "Keyboard", "KeyboardModule should be named 'Keyboard'")
    }

    func testKeyboardModuleDismissDoesNotCrash() {
        let module = KeyboardModule()
        let expectation = self.expectation(description: "dismiss callback")

        module.invoke(method: "dismiss", args: []) { _, error in
            XCTAssertNil(error, "dismiss should not return an error")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testKeyboardModuleGetHeight() {
        let module = KeyboardModule()
        let expectation = self.expectation(description: "getHeight callback")

        module.invoke(method: "getHeight", args: []) { result, error in
            XCTAssertNil(error, "getHeight should not return an error")
            XCTAssertNotNil(result, "getHeight should return keyboard info")

            if let info = result as? [String: Any] {
                XCTAssertNotNil(info["height"], "Should include height")
                XCTAssertNotNil(info["isVisible"], "Should include isVisible")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testKeyboardModuleUnknownMethod() {
        let module = KeyboardModule()
        let expectation = self.expectation(description: "unknown method")

        module.invoke(method: "nonexistent", args: []) { _, error in
            XCTAssertNotNil(error, "Unknown method should return an error")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - NativeModule Protocol Default Implementation

    func testNativeModuleDefaultInvokeSyncReturnsNil() {
        let module = HapticsModule()
        let result = module.invokeSync(method: "vibrate", args: ["light"])
        XCTAssertNil(result, "Default invokeSync should return nil")
    }
}
#endif
