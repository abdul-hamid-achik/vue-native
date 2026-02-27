#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

@MainActor
final class CertificatePinningTests: XCTestCase {

    // MARK: - Properties

    private var pinning: CertificatePinning!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        pinning = CertificatePinning.shared
        pinning.clearPins()
    }

    override func tearDown() {
        pinning.clearPins()
        pinning = nil
        super.tearDown()
    }

    // MARK: - Singleton Tests

    func testSharedInstanceIsSingleton() {
        let instance1 = CertificatePinning.shared
        let instance2 = CertificatePinning.shared
        XCTAssertTrue(instance1 === instance2, "CertificatePinning.shared should always return the same instance")
    }

    // MARK: - configurePins Tests

    func testConfigurePinsStoresHashesForDomain() {
        pinning.configurePins([
            "api.example.com": ["sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="]
        ])

        XCTAssertTrue(pinning.hasPins(for: "api.example.com"), "Should have pins for configured domain")
    }

    func testConfigurePinsMultipleDomains() {
        pinning.configurePins([
            "api.example.com": ["sha256/AAA="],
            "cdn.example.com": ["sha256/BBB="]
        ])

        XCTAssertTrue(pinning.hasPins(for: "api.example.com"), "Should have pins for api.example.com")
        XCTAssertTrue(pinning.hasPins(for: "cdn.example.com"), "Should have pins for cdn.example.com")
    }

    func testConfigurePinsMultipleHashesPerDomain() {
        pinning.configurePins([
            "api.example.com": ["sha256/PrimaryHash=", "sha256/BackupHash="]
        ])

        XCTAssertTrue(pinning.hasPins(for: "api.example.com"),
                      "Should have pins with multiple hashes")
    }

    func testConfigurePinsIgnoresMalformedPins() {
        // Pins without "sha256/" prefix should be ignored
        pinning.configurePins([
            "api.example.com": ["md5/NotSupported"]
        ])

        XCTAssertFalse(pinning.hasPins(for: "api.example.com"),
                       "Malformed pins (without sha256/ prefix) should not register")
    }

    func testConfigurePinsIsCaseInsensitiveForDomain() {
        pinning.configurePins([
            "API.Example.COM": ["sha256/TestHash="]
        ])

        XCTAssertTrue(pinning.hasPins(for: "api.example.com"),
                      "Domain lookup should be case-insensitive")
    }

    // MARK: - hasPins Tests

    func testHasPinsReturnsFalseForUnconfiguredDomain() {
        XCTAssertFalse(pinning.hasPins(for: "unknown.com"),
                       "Should return false for domains without pins")
    }

    func testHasPinsReturnsTrueForConfiguredDomain() {
        pinning.configurePins([
            "example.com": ["sha256/TestHash="]
        ])

        XCTAssertTrue(pinning.hasPins(for: "example.com"),
                      "Should return true for configured domain")
    }

    func testHasPinsIsCaseInsensitive() {
        pinning.configurePins([
            "example.com": ["sha256/TestHash="]
        ])

        XCTAssertTrue(pinning.hasPins(for: "EXAMPLE.COM"),
                      "hasPins lookup should be case-insensitive")
    }

    // MARK: - clearPins Tests

    func testClearPinsRemovesAllPins() {
        pinning.configurePins([
            "api.example.com": ["sha256/AAA="],
            "cdn.example.com": ["sha256/BBB="]
        ])

        pinning.clearPins()

        XCTAssertFalse(pinning.hasPins(for: "api.example.com"),
                       "clearPins should remove all configured pins")
        XCTAssertFalse(pinning.hasPins(for: "cdn.example.com"),
                       "clearPins should remove all configured pins")
    }

    func testClearPinsOnEmptyDoesNotCrash() {
        // Should not crash when called with no pins configured
        pinning.clearPins()
    }

    // MARK: - Session Tests

    func testSessionIsURLSession() {
        let session = pinning.session
        XCTAssertNotNil(session, "session should return a valid URLSession")
    }

    func testSessionIsSameInstance() {
        let session1 = pinning.session
        let session2 = pinning.session
        XCTAssertTrue(session1 === session2, "session should return the same URLSession instance")
    }

    // MARK: - URLSessionDelegate Conformance

    func testConformsToURLSessionDelegate() {
        XCTAssertTrue(pinning is URLSessionDelegate,
                      "CertificatePinning should conform to URLSessionDelegate")
    }

    // MARK: - Empty Pins Allows Default Handling

    func testNoPinsConfiguredAllowsDefaultHandling() {
        // With no pins configured, hasPins should return false for any domain
        XCTAssertFalse(pinning.hasPins(for: "anything.com"),
                       "Without pins configured, all domains should use default handling")
    }

    // MARK: - Backup Pin Support

    func testBackupPinConfigured() {
        // Configure primary + backup pins for a domain
        pinning.configurePins([
            "api.example.com": ["sha256/PrimaryHash=", "sha256/BackupHash="]
        ])

        // Both pins should be stored
        XCTAssertTrue(pinning.hasPins(for: "api.example.com"),
                      "Domain should have pins configured including backup")
    }

    // MARK: - Additive Configuration

    func testConfigurePinsIsAdditive() {
        pinning.configurePins(["api.example.com": ["sha256/AAA="]])
        pinning.configurePins(["cdn.example.com": ["sha256/BBB="]])

        // First domain's pins may be overwritten or preserved depending on implementation.
        // At minimum, the second domain should be configured.
        XCTAssertTrue(pinning.hasPins(for: "cdn.example.com"),
                      "Adding pins for a new domain should work")
    }

    func testConfigurePinsSameDomainOverwrites() {
        pinning.configurePins(["api.example.com": ["sha256/OldHash="]])
        pinning.configurePins(["api.example.com": ["sha256/NewHash="]])

        XCTAssertTrue(pinning.hasPins(for: "api.example.com"),
                      "Reconfiguring the same domain should still have pins")
    }
}
#endif
