#if canImport(UIKit)
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
}
#endif
