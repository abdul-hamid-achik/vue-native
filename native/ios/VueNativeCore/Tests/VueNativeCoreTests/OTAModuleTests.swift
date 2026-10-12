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
        OTAModule.resetPublisherKeyForTesting()
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
        OTAModule.resetPublisherKeyForTesting()
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: bundleDirectory)
        module = nil
        defaults = nil
        bundleDirectory = nil
        try super.tearDownWithError()
    }

    /// Build a module whose publisher key comes from native configuration — the
    /// only supported source. `publisherKeyBase64` stands in for the Info.plist
    /// entry / `OTAModule.configurePublisherKey`.
    private func makeModule(publisherKeyBase64: String?, requireSignedManifest: Bool? = nil) throws -> OTAModule {
        OTAModule(
            bridge: NativeBridge.shared,
            defaults: defaults,
            bundleDirectory: bundleDirectory,
            publisherKeyBase64: publisherKeyBase64,
            requireSignedManifest: requireSignedManifest
        )
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

    /// P0-1: the key must not be settable by the code it authenticates.
    func testSetVerifyKeyFromJavaScriptIsRejectedAndInstallsNoKey() throws {
        let privateKey = P256.Signing.PrivateKey()
        let spkiBase64 = privateKey.publicKey.derRepresentation.base64EncodedString()

        let valid = invoke("setVerifyKey", args: [spkiBase64])
        XCTAssertNil(valid.result)
        XCTAssertEqual(valid.error, OTAModule.setVerifyKeyRejectionMessage)

        let malformed = invoke("setVerifyKey", args: ["!!!not-base64!!!"])
        XCTAssertNil(malformed.result)
        XCTAssertEqual(malformed.error, OTAModule.setVerifyKeyRejectionMessage)

        // The rejected call must not have installed anything: verification still
        // fails closed, which is what an attacker-installed key would have avoided.
        let bundleData = Data("globalThis.__attacker = true;".utf8)
        let hash = OTAModule.sha256(data: bundleData)
        let signature = try privateKey.signature(for: bundleData).derRepresentation.base64EncodedString()
        XCTAssertEqual(
            module.verificationError(for: bundleData, expectedHash: hash, signature: signature, version: "1.0.0"),
            OTAModule.missingPublisherKeyMessage
        )
    }

    /// A manifest signed with the exact pipeline the docs give publishers:
    /// `printf 'vue-native-ota-v1\n%s\n%s' "$VERSION" "$SHA256" | openssl dgst -sha256
    /// -sign private.pem | openssl base64 -A`, with the key from `openssl ecparam
    /// -name prime256v1 -genkey`. Pins the documented format to the verifier.
    func testManifestSignedWithTheDocumentedOpenSSLPipelineVerifies() throws {
        let configured = try makeModule(publisherKeyBase64: "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEC0CpFblo4nH7yscLDLCutyC/zM1AEJtMGteAqD8cRJ6N0zaPFZHLO1kHs5oa2eZXh6ILEn2EcFwR4K0TKTTYVw==")
        let bundleData = Data("globalThis.__vnOtaFixture = 1;\n".utf8)
        let hash = "95e9ddb8598755e6c5c9cd289c6552a51cd1c98eb44594f005481f73d7ebab12"
        XCTAssertEqual(OTAModule.sha256(data: bundleData), hash)

        let signature = "MEUCIAf/iX48eiA/au+qyc5Z13TMmmbZC+N/EJF61/8hEr8UAiEA5Q+0GkZTuqEGyH9XUaBfUH+VP3V/v0oXttJSHXb5ccg="
        XCTAssertNil(configured.verificationError(for: bundleData, expectedHash: hash, signature: signature, version: "1.4.2"))

        // `openssl base64` without -A (and GNU `base64`) wraps the output. The
        // verifier must accept the same signature split across lines.
        let wrapped = "MEUCIAf/iX48eiA/au+qyc5Z13TMmmbZC+N/EJF61/8hEr8UAiEA5Q+0GkZTuqEG\nyH9XUaBfUH+VP3V/v0oXttJSHXb5ccg=\n"
        XCTAssertNil(configured.verificationError(for: bundleData, expectedHash: hash, signature: wrapped, version: "1.4.2"))

        // The signature binds the version: relabelling the bundle fails.
        XCTAssertEqual(
            configured.verificationError(for: bundleData, expectedHash: hash, signature: signature, version: "1.4.3"),
            "OTA update rejected: signature verification failed"
        )
    }

    func testVerificationFailsClosedWithoutANativePublisherKey() throws {
        // No key configured anywhere: integrity alone must NOT be enough.
        let bundleData = Data("globalThis.__unsigned = true;".utf8)
        let hash = OTAModule.sha256(data: bundleData)

        XCTAssertEqual(
            module.verificationError(for: bundleData, expectedHash: hash, signature: nil, version: "1.0.0"),
            OTAModule.missingPublisherKeyMessage
        )
        // Even a signature is useless without a key to check it against.
        let signature = try P256.Signing.PrivateKey()
            .signature(for: bundleData).derRepresentation.base64EncodedString()
        XCTAssertEqual(
            module.verificationError(for: bundleData, expectedHash: hash, signature: signature, version: "1.0.0"),
            OTAModule.missingPublisherKeyMessage
        )

        // A hash mismatch is still reported as such (it is checked first).
        let badHash = String(repeating: "0", count: 64)
        XCTAssertEqual(
            module.verificationError(for: bundleData, expectedHash: badHash, signature: nil, version: "1.0.0"),
            "Bundle integrity check failed. Expected: \(badHash), got: \(hash)"
        )
    }

    func testHostConfiguredKeyIsHonouredAndJsKeyIsNot() throws {
        let privateKey = P256.Signing.PrivateKey()
        try OTAModule.configurePublisherKey(
            base64SPKI: privateKey.publicKey.derRepresentation.base64EncodedString()
        )
        XCTAssertThrowsError(try OTAModule.configurePublisherKey(base64SPKI: "!!!not-base64!!!"))
        XCTAssertThrowsError(
            try OTAModule.configurePublisherKey(
                base64SPKI: Data("definitely not a key".utf8).base64EncodedString()
            )
        )

        // A module built after the host configured the key picks it up.
        let configured = try makeModule(publisherKeyBase64: nil)
        let bundleData = Data("globalThis.__hostSigned = true;".utf8)
        let hash = OTAModule.sha256(data: bundleData)
        let signature = try privateKey.signature(for: bundleData).derRepresentation.base64EncodedString()
        XCTAssertNil(configured.verificationError(for: bundleData, expectedHash: hash, signature: signature, version: "1.0.0"))
        configured.destroy()
    }

    func testSignatureVerificationEndToEndWithRealKeyVector() throws {
        // Real cryptographic vector: generate a P-256 key pair, sign the raw
        // bundle bytes, and drive the production verification path through it.
        // The key arrives via NATIVE configuration, never from JS.
        let privateKey = P256.Signing.PrivateKey()
        let signed = try makeModule(
            publisherKeyBase64: privateKey.publicKey.derRepresentation.base64EncodedString()
        )
        defer { signed.destroy() }

        let bundleData = Data("globalThis.__signed = true;".utf8)
        let hash = OTAModule.sha256(data: bundleData)
        let signatureBase64 = try privateKey.signature(for: bundleData).derRepresentation.base64EncodedString()

        // (a) A valid signature over the exact bytes passes. This also proves the
        // convention empirically: production verifies `for: data` (raw bytes) and
        // the test signs `for: data` (raw bytes) — a digest-based convention would
        // fail here.
        XCTAssertNil(
            signed.verificationError(for: bundleData, expectedHash: hash, signature: signatureBase64, version: "1.0.0"),
            "a valid signature over the bundle bytes must pass"
        )

        // (b) A tampered bundle (re-hashed so integrity passes) signed with the
        // ORIGINAL signature is rejected as a signature failure.
        let tamperedData = Data("globalThis.__signed = false;".utf8)
        let tamperedHash = OTAModule.sha256(data: tamperedData)
        let tamperedError = signed.verificationError(
            for: tamperedData,
            expectedHash: tamperedHash,
            signature: signatureBase64,
            version: "1.0.0"
        )
        XCTAssertEqual(tamperedError, "OTA update rejected: signature verification failed")

        // (c) With a verify key configured, a missing signature is rejected.
        let missingError = signed.verificationError(for: bundleData, expectedHash: hash, signature: nil, version: "1.0.0")
        XCTAssertEqual(missingError, "OTA update rejected: signature required when a verify key is configured")

        // An empty signature is treated the same as a missing one.
        let emptyError = signed.verificationError(for: bundleData, expectedHash: hash, signature: "", version: "1.0.0")
        XCTAssertEqual(emptyError, "OTA update rejected: signature required when a verify key is configured")

        // Malformed signature bytes are rejected as a verification failure.
        let malformedError = signed.verificationError(
            for: bundleData,
            expectedHash: hash,
            signature: Data("garbage".utf8).base64EncodedString(),
            version: "1.0.0"
        )
        XCTAssertEqual(malformedError, "OTA update rejected: signature verification failed")
    }

    func testSignatureFromWrongKeyIsRejected() throws {
        let publisherKey = P256.Signing.PrivateKey()
        let attackerKey = P256.Signing.PrivateKey()
        let configured = try makeModule(
            publisherKeyBase64: publisherKey.publicKey.derRepresentation.base64EncodedString()
        )
        defer { configured.destroy() }

        let bundleData = Data("globalThis.__bundle = 1;".utf8)
        let hash = OTAModule.sha256(data: bundleData)
        // Attacker signs the same bytes with a different key.
        let attackerSignature = try attackerKey.signature(for: bundleData).derRepresentation.base64EncodedString()

        XCTAssertEqual(
            configured.verificationError(for: bundleData, expectedHash: hash, signature: attackerSignature, version: "1.0.0"),
            "OTA update rejected: signature verification failed",
            "a signature from a non-publisher key must be rejected"
        )
    }

    func testMalformedNativeKeyMaterialFailsClosed() throws {
        let broken = try makeModule(publisherKeyBase64: Data("not a key".utf8).base64EncodedString())
        defer { broken.destroy() }

        let bundleData = Data("globalThis.__broken = true;".utf8)
        XCTAssertEqual(
            broken.verificationError(for: bundleData, expectedHash: OTAModule.sha256(data: bundleData), signature: nil, version: "1.0.0"),
            OTAModule.missingPublisherKeyMessage,
            "undecodable native key material must not fall back to hash-only"
        )
    }

    // MARK: - Anti-downgrade

    func testCompareVersionsOrdersDottedNumerics() {
        XCTAssertEqual(OTAModule.compareVersions("1.0.0", "1.0.1"), -1)
        XCTAssertEqual(OTAModule.compareVersions("1.0.1", "1.0.0"), 1)
        XCTAssertEqual(OTAModule.compareVersions("1.0.0", "1.0.0"), 0)
        // Numeric, not lexical, per segment.
        XCTAssertEqual(OTAModule.compareVersions("1.10.0", "1.9.0"), 1)
        XCTAssertEqual(OTAModule.compareVersions("2.0.0", "10.0.0"), -1)
        // A missing segment is zero.
        XCTAssertEqual(OTAModule.compareVersions("2.0", "2.0.0"), 0)
        XCTAssertEqual(OTAModule.compareVersions("2.0.1", "2.0"), 1)
        // Non-numeric segments compare lexically.
        XCTAssertEqual(OTAModule.compareVersions("v1", "v2"), -1)
        XCTAssertEqual(OTAModule.compareVersions("v2", "v1"), 1)
        XCTAssertEqual(OTAModule.compareVersions("v1", "v1"), 0)
    }

    func testIsStrictlyNewerTreatsEmbeddedAsOldest() {
        XCTAssertTrue(OTAModule.isStrictlyNewer(candidate: "0.0.1", current: nil))
        XCTAssertTrue(OTAModule.isStrictlyNewer(candidate: "0.0.1", current: ""))
        XCTAssertTrue(OTAModule.isStrictlyNewer(candidate: "1.0.1", current: "1.0.0"))
        XCTAssertFalse(OTAModule.isStrictlyNewer(candidate: "1.0.0", current: "1.0.0"))
        XCTAssertFalse(OTAModule.isStrictlyNewer(candidate: "0.9.0", current: "1.0.0"))
    }

    func testApplyUpdateRejectsDowngradeToAnOlderSignedBundle() throws {
        let privateKey = P256.Signing.PrivateKey()
        let configured = try makeModule(
            publisherKeyBase64: privateKey.publicKey.derRepresentation.base64EncodedString()
        )
        defer { configured.destroy() }

        // Install 2.0.0, then try to apply a staged 1.0.0 over it.
        _ = try stageBundle(source: "globalThis.__v = 2;", version: "2.0.0")
        XCTAssertNil(invokeOn(configured, "applyUpdate").error)
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "2.0.0")

        _ = try stageBundle(source: "globalThis.__v = 1;", version: "1.0.0")
        let downgrade = invokeOn(configured, "applyUpdate")
        XCTAssertNil(downgrade.result)
        XCTAssertEqual(
            downgrade.error,
            OTAModule.downgradeMessage(candidate: "1.0.0", current: "2.0.0")
        )
        // The installed version must be untouched.
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "2.0.0")

        // An equal version is not "strictly greater" either.
        _ = try stageBundle(source: "globalThis.__v = 2;", version: "2.0.0")
        let same = invokeOn(configured, "applyUpdate")
        XCTAssertNil(same.result)
        XCTAssertEqual(same.error, OTAModule.downgradeMessage(candidate: "2.0.0", current: "2.0.0"))
    }

    func testDownloadUpdateRejectsDowngradeBeforeAnyNetworkRequest() throws {
        _ = try stageBundle(source: "globalThis.__v = 3;", version: "3.0.0")
        XCTAssertNil(invoke("applyUpdate").error)

        // A syntactically valid HTTPS URL and hash: only the version can reject
        // this, and it must do so without touching the network.
        let response = invokeAsync(
            "downloadUpdate",
            args: ["https://example.invalid/bundle.js", String(repeating: "a", count: 64), "2.9.9"]
        )
        XCTAssertNil(response.result)
        XCTAssertEqual(
            response.error,
            OTAModule.downgradeMessage(candidate: "2.9.9", current: "3.0.0")
        )
        XCTAssertNil(defaults.string(forKey: OTAModule.pendingBundlePathKey))
    }

    func testRollbackIsNotVersionGated() throws {
        _ = try stageBundle(source: "globalThis.__v = 1;", version: "1.0.0")
        XCTAssertNil(invoke("applyUpdate").error)
        _ = try stageBundle(source: "globalThis.__v = 2;", version: "2.0.0")
        XCTAssertNil(invoke("applyUpdate").error)
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "2.0.0")

        // Rolling back to an OLDER version must still work — that is its purpose.
        XCTAssertNil(invoke("rollback").error)
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "1.0.0")
    }

    // MARK: - Version parsing and precedence

    func testVersionParserAcceptsTheDocumentedShapes() {
        for text in [
            "1.2.3", "v1.8.0", "V2", "1.2", "1.2.3.4", "1.2.3-beta", "1.2.3-alpha.2",
            "1.2.3-alpha-1", "1.2.3+build.7", "1.2.3-rc.1+exp.sha.5114f85",
        ] {
            XCTAssertNotNil(OTAVersion(text), "\(text) should parse")
        }
    }

    func testVersionParserRejectsMalformedVersions() {
        for text in [
            "a", "", "v", "1..2", "1.2.3.4.5", "1.2.x", "1234567890", "-1.2",
            "1.2.3-", "1.2.3-alpha..1", "1.2.3-bad_id", "1.2.3+", "1.2.3+build..1",
        ] {
            XCTAssertNil(OTAVersion(text), "\(text) should be rejected")
        }
    }

    func testSemverPrecedenceOrdersVersions() {
        XCTAssertEqual(OTAModule.compareVersions("v1.8.0", "1.9.0"), -1)
        XCTAssertEqual(OTAModule.compareVersions("1.10.0", "1.9.0"), 1)
        XCTAssertEqual(OTAModule.compareVersions("1.2.3-beta", "1.2.3"), -1)
        XCTAssertEqual(OTAModule.compareVersions("1.2.3", "1.2.3-rc.9"), 1)
        XCTAssertEqual(OTAModule.compareVersions("1.2.3-alpha.2", "1.2.3-alpha.10"), -1)
        XCTAssertEqual(OTAModule.compareVersions("1.2", "1.2.0"), 0)
        // A shorter identifier list is lower when it is a prefix.
        XCTAssertEqual(OTAModule.compareVersions("1.0.0-alpha", "1.0.0-alpha.1"), -1)
        // Numeric identifiers rank below alphanumeric ones.
        XCTAssertEqual(OTAModule.compareVersions("1.0.0-alpha.1", "1.0.0-alpha.beta"), -1)
        // Numeric identifiers compare by value, and by ASCII otherwise.
        XCTAssertEqual(OTAModule.compareVersions("1.0.0-9", "1.0.0-10"), -1)
        XCTAssertEqual(OTAModule.compareVersions("1.0.0-beta.11", "1.0.0-rc.1"), -1)
        // Long numeric identifiers must not overflow.
        XCTAssertEqual(
            OTAModule.compareVersions("1.0.0-99999999999999999999", "1.0.0-100000000000000000000"),
            -1
        )
    }

    func testBuildMetadataIsIgnoredForOrdering() {
        XCTAssertEqual(OTAModule.compareVersions("1.2.3+a", "1.2.3+b"), 0)
        XCTAssertEqual(OTAModule.compareVersions("1.2.3+a", "1.2.3"), 0)
    }

    func testInvalidVersionsSortBelowValidOnes() {
        XCTAssertEqual(OTAModule.compareVersions("a", "1.0.0"), -1)
        XCTAssertEqual(OTAModule.compareVersions("1.0.0", "garbage"), 1)
        // So an unparseable stored version never blocks a valid candidate.
        XCTAssertTrue(OTAModule.isStrictlyNewer(candidate: "0.0.1", current: "garbage"))
        XCTAssertFalse(OTAModule.isStrictlyNewer(candidate: "garbage", current: "1.0.0"))
    }

    // MARK: - Monotonic floor

    func testRollbackDoesNotLowerTheAcceptedFloor() throws {
        _ = try stageBundle(source: "globalThis.__v = 2;", version: "2.0.0")
        XCTAssertNil(invoke("applyUpdate").error)
        XCTAssertNil(invoke("rollback").error)
        XCTAssertNil(
            OTAModule.activeBundleURL(defaults: defaults, bundleDirectory: bundleDirectory),
            "rollback should reach the embedded bundle"
        )
        XCTAssertEqual(defaults.string(forKey: OTAModule.highestAcceptedVersionKey), "2.0.0")

        // The embedded bundle is installed, but 2.0.0 was accepted before, so an
        // older release is still refused on both entry points.
        let download = invokeAsync(
            "downloadUpdate",
            args: ["https://example.invalid/bundle.js", String(repeating: "a", count: 64), "1.5.0"]
        )
        XCTAssertEqual(download.error, OTAModule.downgradeMessage(candidate: "1.5.0", current: "2.0.0"))

        _ = try stageBundle(source: "globalThis.__v = 15;", version: "1.5.0")
        XCTAssertEqual(
            invoke("applyUpdate").error,
            OTAModule.downgradeMessage(candidate: "1.5.0", current: "2.0.0")
        )

        _ = try stageBundle(source: "globalThis.__v = 201;", version: "2.0.1")
        XCTAssertNil(invoke("applyUpdate").error)
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "2.0.1")
        XCTAssertEqual(defaults.string(forKey: OTAModule.highestAcceptedVersionKey), "2.0.1")
    }

    func testInvalidCandidateVersionIsRejectedByDownloadAndApply() throws {
        let download = invokeAsync(
            "downloadUpdate",
            args: ["https://example.invalid/bundle.js", String(repeating: "a", count: 64), "1.2.x"]
        )
        XCTAssertNil(download.result)
        XCTAssertEqual(download.error, OTAModule.invalidVersionMessage("1.2.x"))

        _ = try stageBundle(source: "globalThis.__v = 9;", version: "a")
        XCTAssertEqual(invoke("applyUpdate").error, OTAModule.invalidVersionMessage("a"))
        XCTAssertNil(defaults.string(forKey: OTAModule.currentVersionKey))
    }

    func testUnparseableStoredFloorIsIgnored() throws {
        defaults.set("not-a-version", forKey: OTAModule.highestAcceptedVersionKey)

        _ = try stageBundle(source: "globalThis.__v = 1;", version: "1.0.0")
        XCTAssertNil(invoke("applyUpdate").error, "bad stored state must not lock the device out")
        XCTAssertEqual(defaults.string(forKey: OTAModule.highestAcceptedVersionKey), "1.0.0")
    }

    // MARK: - Signed manifest

    /// Signs the manifest message as the publisher does, built here independently
    /// of production: `vue-native-ota-v1\n<version>\n<sha256>`.
    private func manifestSignature(
        _ key: P256.Signing.PrivateKey,
        version: String,
        bundle: Data
    ) throws -> String {
        let message = Data("vue-native-ota-v1\n\(version)\n\(OTAModule.sha256(data: bundle))".utf8)
        return try key.signature(for: message).derRepresentation.base64EncodedString()
    }

    func testSignedManifestForTheClaimedVersionIsAccepted() throws {
        let key = P256.Signing.PrivateKey()
        let spki = key.publicKey.derRepresentation.base64EncodedString()
        let bundle = Data("globalThis.__manifest = true;".utf8)
        let hash = OTAModule.sha256(data: bundle)
        let signature = try manifestSignature(key, version: "2.0.0", bundle: bundle)

        let lenient = try makeModule(publisherKeyBase64: spki, requireSignedManifest: false)
        defer { lenient.destroy() }
        XCTAssertNil(
            lenient.verificationError(for: bundle, expectedHash: hash, signature: signature, version: "2.0.0")
        )

        let strict = try makeModule(publisherKeyBase64: spki, requireSignedManifest: true)
        defer { strict.destroy() }
        XCTAssertNil(
            strict.verificationError(for: bundle, expectedHash: hash, signature: signature, version: "2.0.0"),
            "a manifest signature is accepted even when the manifest is required"
        )
    }

    func testSignedManifestForAnotherVersionIsRejected() throws {
        let key = P256.Signing.PrivateKey()
        let spki = key.publicKey.derRepresentation.base64EncodedString()
        let bundle = Data("globalThis.__manifest = 2;".utf8)
        let hash = OTAModule.sha256(data: bundle)
        // Signed for 1.0.0, but the update claims 1.0.1: the version is authenticated.
        let signature = try manifestSignature(key, version: "1.0.0", bundle: bundle)

        for required in [false, true] {
            let configured = try makeModule(publisherKeyBase64: spki, requireSignedManifest: required)
            defer { configured.destroy() }
            XCTAssertEqual(
                configured.verificationError(for: bundle, expectedHash: hash, signature: signature, version: "1.0.1"),
                "OTA update rejected: signature verification failed",
                "a manifest for a different version must fail (required: \(required))"
            )
        }
    }

    func testLegacyBundleSignatureIsAcceptedOnlyWhileTheManifestIsOptional() throws {
        let key = P256.Signing.PrivateKey()
        let spki = key.publicKey.derRepresentation.base64EncodedString()
        let bundle = Data("globalThis.__legacy = true;".utf8)
        let hash = OTAModule.sha256(data: bundle)
        let legacySignature = try key.signature(for: bundle).derRepresentation.base64EncodedString()

        let optional = try makeModule(publisherKeyBase64: spki, requireSignedManifest: false)
        defer { optional.destroy() }
        XCTAssertNil(
            optional.verificationError(for: bundle, expectedHash: hash, signature: legacySignature, version: "3.0.0"),
            "the legacy format keeps working while the manifest is optional"
        )

        let required = try makeModule(publisherKeyBase64: spki, requireSignedManifest: true)
        defer { required.destroy() }
        XCTAssertEqual(
            required.verificationError(for: bundle, expectedHash: hash, signature: legacySignature, version: "3.0.0"),
            "OTA update rejected: signed manifest required (legacy bundle-bytes signature)"
        )
    }

    func testMissingSignatureStaysRejectedWhenTheManifestIsRequired() throws {
        let key = P256.Signing.PrivateKey()
        let required = try makeModule(
            publisherKeyBase64: key.publicKey.derRepresentation.base64EncodedString(),
            requireSignedManifest: true
        )
        defer { required.destroy() }

        let bundle = Data("globalThis.__unsigned = true;".utf8)
        XCTAssertEqual(
            required.verificationError(
                for: bundle,
                expectedHash: OTAModule.sha256(data: bundle),
                signature: nil,
                version: "1.0.0"
            ),
            "OTA update rejected: signature required when a verify key is configured"
        )
    }

    func testSignedManifestRequirementCanBeConfiguredNatively() throws {
        // Default: the flag is off when nothing is configured.
        XCTAssertFalse(OTAModule.signedManifestRequired(bundle: Bundle(for: OTAModuleTests.self)))

        let key = P256.Signing.PrivateKey()
        OTAModule.configureRequireSignedManifest(true)
        // No injected flag: the module resolves the host-configured value.
        let host = try makeModule(publisherKeyBase64: key.publicKey.derRepresentation.base64EncodedString())
        defer { host.destroy() }

        let bundle = Data("globalThis.__host = true;".utf8)
        let legacySignature = try key.signature(for: bundle).derRepresentation.base64EncodedString()
        XCTAssertEqual(
            host.verificationError(
                for: bundle,
                expectedHash: OTAModule.sha256(data: bundle),
                signature: legacySignature,
                version: "1.0.0"
            ),
            OTAModule.signedManifestRequiredMessage
        )
    }

    private func invokeOn(
        _ target: OTAModule,
        _ method: String,
        args: [Any] = []
    ) -> (result: Any?, error: String?) {
        var result: Any?
        var error: String?
        target.invoke(method: method, args: args) { value, callbackError in
            result = value
            error = callbackError
        }
        return (result, error)
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
