import XCTest
@testable import VueNativeShared

final class VueNativeSharedTests: XCTestCase {
    func testModuleRegistration() {
        let registry = NativeModuleRegistry.shared
        let module = AsyncStorageModule()
        registry.register(module)
        // If we get here without crashing, registration works
        XCTAssertTrue(true)
    }

    func testEventThrottleInit() {
        var callCount = 0
        let throttle = EventThrottle(interval: 0.016) { _ in
            callCount += 1
        }
        throttle.fire("test")
        XCTAssertEqual(callCount, 1)
    }

    func testCertificatePinningNoPins() {
        let pinning = CertificatePinning.shared
        XCTAssertFalse(pinning.hasPins(for: "example.com"))
    }

    func testCertificatePinningConfigure() {
        let pinning = CertificatePinning.shared
        pinning.configurePins(["test.com": ["sha256/abc123"]])
        XCTAssertTrue(pinning.hasPins(for: "test.com"))
        pinning.clearPins()
        XCTAssertFalse(pinning.hasPins(for: "test.com"))
    }

    func testSharedJSPolyfillsJSONEncode() {
        let result = SharedJSPolyfillsJSON.encode("hello")
        XCTAssertEqual(result, "\"hello\"")
    }

    func testSharedJSPolyfillsJSONEncodeSpecialChars() {
        let result = SharedJSPolyfillsJSON.encode("line1\nline2")
        XCTAssertTrue(result.contains("\\n"))
    }
}
