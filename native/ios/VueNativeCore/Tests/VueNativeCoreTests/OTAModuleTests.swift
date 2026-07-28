#if canImport(UIKit)
import CryptoKit
import Foundation
import XCTest
@testable import VueNativeCore

@MainActor
final class OTAModuleTests: XCTestCase {
    private var defaults: UserDefaults!
    private var bundleDirectory: URL!
    private var module: OTAModule!
    private var suiteName = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "VueNativeCore.OTAModuleTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        bundleDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VueNativeCore-OTA-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)
        module = OTAModule(
            bridge: NativeBridge.shared,
            defaults: defaults,
            bundleDirectory: bundleDirectory
        )
    }

    override func tearDownWithError() throws {
        module.destroy()
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: bundleDirectory)
        module = nil
        defaults = nil
        bundleDirectory = nil
        try super.tearDownWithError()
    }

    func testVerifyAndApplyPersistOfferedVersionAndHash() throws {
        let staged = try stageBundle(source: "globalThis.__otaVersion = 2;", version: "2.4.0")

        let verified = invoke("verifyBundle")
        XCTAssertNil(verified.error)
        XCTAssertEqual((verified.result as? [String: Any])?["version"] as? String, "2.4.0")

        let applied = invoke("applyUpdate")
        XCTAssertNil(applied.error)
        XCTAssertEqual((applied.result as? [String: Any])?["version"] as? String, "2.4.0")
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "2.4.0")
        XCTAssertEqual(defaults.string(forKey: OTAModule.bundleHashKey), staged.hash)
        XCTAssertEqual(
            OTAModule.activeBundleURL(
                defaults: defaults,
                bundleDirectory: bundleDirectory
            ),
            staged.url
        )

        let current = invoke("getCurrentVersion")
        let currentInfo = current.result as? [String: Any]
        XCTAssertEqual(currentInfo?["version"] as? String, "2.4.0")
        XCTAssertEqual(currentInfo?["isUsingOTA"] as? Bool, true)
    }

    func testCleanupPartialDownloadRemovesPendingStateAndFile() throws {
        let staged = try stageBundle(source: "globalThis.__pending = true;", version: "3.0.0")

        let cleaned = invoke("cleanupPartialDownload")

        XCTAssertNil(cleaned.error)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.url.path))
        XCTAssertNil(defaults.string(forKey: OTAModule.pendingBundlePathKey))
        XCTAssertNil(defaults.string(forKey: OTAModule.pendingVersionKey))
        XCTAssertNil(defaults.string(forKey: OTAModule.pendingBundleHashKey))
    }

    func testActiveResolverRejectsTamperedBundleAndClearsAppliedState() throws {
        let staged = try stageBundle(source: "globalThis.__safe = true;", version: "4.0.0")
        XCTAssertNil(invoke("applyUpdate").error)

        try Data("globalThis.__tampered = true;".utf8).write(to: staged.url, options: .atomic)

        XCTAssertNil(
            OTAModule.activeBundleURL(
                defaults: defaults,
                bundleDirectory: bundleDirectory
            )
        )
        XCTAssertNil(defaults.string(forKey: OTAModule.bundlePathKey))
        XCTAssertNil(defaults.string(forKey: OTAModule.currentVersionKey))
        XCTAssertNil(defaults.string(forKey: OTAModule.bundleHashKey))
    }

    func testRollbackRestoresPreviousContentAddressedBundle() throws {
        let first = try stageBundle(source: "globalThis.__otaVersion = 1;", version: "1.0.0")
        XCTAssertNil(invoke("applyUpdate").error)
        let second = try stageBundle(source: "globalThis.__otaVersion = 2;", version: "2.0.0")
        XCTAssertNil(invoke("applyUpdate").error)

        let rolledBack = invoke("rollback")

        XCTAssertNil(rolledBack.error)
        XCTAssertEqual((rolledBack.result as? [String: Any])?["toEmbedded"] as? Bool, false)
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "1.0.0")
        XCTAssertEqual(
            OTAModule.activeBundleURL(
                defaults: defaults,
                bundleDirectory: bundleDirectory
            ),
            first.url
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.url.path))
    }

    func testResolverWillNotReadOrDeleteOutsideManagedDirectory() throws {
        let source = Data("globalThis.__outside = true;".utf8)
        let outsideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VueNativeCore-outside-\(UUID().uuidString).js")
        try source.write(to: outsideURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: outsideURL) }

        defaults.set(outsideURL.path, forKey: OTAModule.bundlePathKey)
        defaults.set("1.0.0", forKey: OTAModule.currentVersionKey)
        defaults.set(OTAModule.sha256(data: source), forKey: OTAModule.bundleHashKey)

        XCTAssertNil(
            OTAModule.activeBundleURL(
                defaults: defaults,
                bundleDirectory: bundleDirectory
            )
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideURL.path))
    }

    func testCheckForUpdateRejectsNonHTTPSSchemes() {
        let http = invokeAsync("checkForUpdate", args: ["http://example.com/manifest"])
        XCTAssertNotNil(http.error)
        XCTAssertTrue(http.error?.contains("HTTPS") == true)

        let ftp = invokeAsync("checkForUpdate", args: ["ftp://example.com/manifest"])
        XCTAssertNotNil(ftp.error)
    }

    func testDownloadUpdateRejectsNonHTTPSSchemes() {
        let hash = String(repeating: "a", count: 64)
        let http = invokeAsync(
            "downloadUpdate",
            args: ["http://example.com/bundle.js", hash, "1.0.0"]
        )
        XCTAssertNotNil(http.error)
        XCTAssertTrue(http.error?.contains("HTTPS") == true)
        XCTAssertNil(defaults.string(forKey: OTAModule.pendingBundlePathKey))
    }

    func testDownloadUpdateValidatesHashAndVersionBeforeNetwork() {
        // A malformed hash is rejected before any network request is attempted.
        let badHash = invokeAsync(
            "downloadUpdate",
            args: ["https://example.com/bundle.js", "not-a-hash", "1.0.0"]
        )
        XCTAssertNotNil(badHash.error)
        XCTAssertTrue(badHash.error?.contains("SHA-256") == true)

        // An empty version is rejected before any network request is attempted.
        let emptyVersion = invokeAsync(
            "downloadUpdate",
            args: ["https://example.com/bundle.js", String(repeating: "a", count: 64), "  "]
        )
        XCTAssertNotNil(emptyVersion.error)
        XCTAssertTrue(emptyVersion.error?.contains("version") == true)
    }

    // MARK: - ECDSA P-256 publisher signature verification

    func testSetVerifyKeyRejectsInvalidKeyMaterial() {
        let badBase64 = invoke("setVerifyKey", args: ["!!!not-base64!!!"])
        XCTAssertNotNil(badBase64.error)

        // Valid base64 but not a P-256 SPKI structure.
        let garbage = Data("definitely not a key".utf8).base64EncodedString()
        let badKey = invoke("setVerifyKey", args: [garbage])
        XCTAssertNotNil(badKey.error)
        XCTAssertTrue(badKey.error?.contains("P-256") == true)
    }

    func testSignatureVerificationEndToEndWithRealKeyVector() throws {
        // Real cryptographic vector: generate a P-256 key pair, sign the raw
        // bundle bytes, and drive the production verification path through it.
        let privateKey = P256.Signing.PrivateKey()
        let spkiBase64 = privateKey.publicKey.derRepresentation.base64EncodedString()

        let configured = invoke("setVerifyKey", args: [spkiBase64])
        XCTAssertNil(configured.error, "a valid SPKI key must be accepted")

        let bundleData = Data("globalThis.__signed = true;".utf8)
        let hash = OTAModule.sha256(data: bundleData)
        let signatureBase64 = try privateKey.signature(for: bundleData).derRepresentation.base64EncodedString()

        // (a) A valid signature over the exact bytes passes. This also proves the
        // convention empirically: production verifies `for: data` (raw bytes) and
        // the test signs `for: data` (raw bytes) — a digest-based convention would
        // fail here.
        XCTAssertNil(
            module.verificationError(for: bundleData, expectedHash: hash, signature: signatureBase64),
            "a valid signature over the bundle bytes must pass"
        )

        // (b) A tampered bundle (re-hashed so integrity passes) signed with the
        // ORIGINAL signature is rejected as a signature failure.
        let tamperedData = Data("globalThis.__signed = false;".utf8)
        let tamperedHash = OTAModule.sha256(data: tamperedData)
        let tamperedError = module.verificationError(
            for: tamperedData,
            expectedHash: tamperedHash,
            signature: signatureBase64
        )
        XCTAssertEqual(tamperedError, "OTA update rejected: signature verification failed")

        // (c) With a verify key configured, a missing signature is rejected.
        let missingError = module.verificationError(for: bundleData, expectedHash: hash, signature: nil)
        XCTAssertEqual(missingError, "OTA update rejected: signature required when a verify key is configured")

        // An empty signature is treated the same as a missing one.
        let emptyError = module.verificationError(for: bundleData, expectedHash: hash, signature: "")
        XCTAssertEqual(emptyError, "OTA update rejected: signature required when a verify key is configured")

        // Malformed signature bytes are rejected as a verification failure.
        let malformedError = module.verificationError(
            for: bundleData,
            expectedHash: hash,
            signature: Data("garbage".utf8).base64EncodedString()
        )
        XCTAssertEqual(malformedError, "OTA update rejected: signature verification failed")
    }

    func testSignatureFromWrongKeyIsRejected() throws {
        let publisherKey = P256.Signing.PrivateKey()
        let attackerKey = P256.Signing.PrivateKey()
        let configured = invoke("setVerifyKey", args: [publisherKey.publicKey.derRepresentation.base64EncodedString()])
        XCTAssertNil(configured.error)

        let bundleData = Data("globalThis.__bundle = 1;".utf8)
        let hash = OTAModule.sha256(data: bundleData)
        // Attacker signs the same bytes with a different key.
        let attackerSignature = try attackerKey.signature(for: bundleData).derRepresentation.base64EncodedString()

        XCTAssertEqual(
            module.verificationError(for: bundleData, expectedHash: hash, signature: attackerSignature),
            "OTA update rejected: signature verification failed",
            "a signature from a non-publisher key must be rejected"
        )
    }

    func testHashOnlyPathWhenNoVerifyKeyConfigured() {
        // No verify key configured: integrity (SHA-256) is enforced, signature is
        // ignored, and publisher authentication is skipped.
        let bundleData = Data("globalThis.__unsigned = true;".utf8)
        let hash = OTAModule.sha256(data: bundleData)

        XCTAssertNil(
            module.verificationError(for: bundleData, expectedHash: hash, signature: nil),
            "without a verify key, a matching hash alone must pass"
        )

        let badHash = String(repeating: "0", count: 64)
        XCTAssertEqual(
            module.verificationError(for: bundleData, expectedHash: badHash, signature: nil),
            "Bundle integrity check failed. Expected: \(badHash), got: \(hash)"
        )
    }

    private func stageBundle(source: String, version: String) throws -> (url: URL, hash: String) {
        let data = Data(source.utf8)
        let hash = OTAModule.sha256(data: data)
        let url = bundleDirectory.appendingPathComponent("bundle-\(hash).js")
        try data.write(to: url, options: .atomic)
        defaults.set(url.path, forKey: OTAModule.pendingBundlePathKey)
        defaults.set(version, forKey: OTAModule.pendingVersionKey)
        defaults.set(hash, forKey: OTAModule.pendingBundleHashKey)
        return (url, hash)
    }

    private func invoke(_ method: String, args: [Any] = []) -> (result: Any?, error: String?) {
        var result: Any?
        var error: String?
        module.invoke(method: method, args: args) { value, callbackError in
            result = value
            error = callbackError
        }
        return (result, error)
    }

    private func invokeAsync(
        _ method: String,
        args: [Any] = [],
        timeout: TimeInterval = 5
    ) -> (result: Any?, error: String?) {
        let completed = expectation(description: "\(method) callback")
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
}
#endif
