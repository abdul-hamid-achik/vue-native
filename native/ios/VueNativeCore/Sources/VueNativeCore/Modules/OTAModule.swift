#if canImport(UIKit)
import CommonCrypto
import Foundation
import UIKit

/// Native module for verified Over-The-Air JavaScript bundle updates.
///
/// OTA state is stored as path/version/hash triples. Bundles are content-addressed,
/// so applying a new update never overwrites the one retained for rollback.
final class OTAModule: NativeModule {
    var moduleName: String { "OTA" }

    static let currentVersionKey = "VueNative.OTA.currentVersion"
    static let bundlePathKey = "VueNative.OTA.bundlePath"
    static let bundleHashKey = "VueNative.OTA.bundleHash"
    static let previousBundlePathKey = "VueNative.OTA.previousBundlePath"
    static let previousVersionKey = "VueNative.OTA.previousVersion"
    static let previousBundleHashKey = "VueNative.OTA.previousBundleHash"
    static let pendingBundlePathKey = "VueNative.OTA.pendingBundlePath"
    static let pendingVersionKey = "VueNative.OTA.pendingVersion"
    static let pendingBundleHashKey = "VueNative.OTA.pendingBundleHash"

    private weak var bridge: NativeBridge?
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let bundleDirectory: URL
    private let requestSession: URLSession
    private let sessionLock = NSLock()
    private var downloadSession: URLSession?
    private var destroyed = false

    init(
        bridge: NativeBridge,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        bundleDirectory: URL? = nil
    ) {
        self.bridge = bridge
        self.defaults = defaults
        self.fileManager = fileManager
        self.bundleDirectory = bundleDirectory ?? Self.defaultBundleDirectory(fileManager: fileManager)
        self.requestSession = URLSession(configuration: .ephemeral)
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "checkForUpdate":
            guard let serverURL = args.first as? String else {
                callback(nil, "checkForUpdate: missing serverUrl")
                return
            }
            checkForUpdate(serverURL: serverURL, callback: callback)

        case "downloadUpdate":
            guard args.count >= 3,
                  let url = args[0] as? String,
                  let expectedHash = args[1] as? String,
                  let version = args[2] as? String else {
                callback(nil, "downloadUpdate requires url, SHA-256 hash, and version")
                return
            }
            downloadUpdate(url: url, expectedHash: expectedHash, version: version, callback: callback)

        case "verifyBundle":
            verifyBundle(callback: callback)

        case "cleanupPartialDownload":
            cleanupPendingBundle(removeFile: true)
            callback(["cleaned": true], nil)

        case "applyUpdate":
            applyUpdate(callback: callback)

        case "rollback":
            rollback(callback: callback)

        case "getCurrentVersion":
            getCurrentVersion(callback: callback)

        default:
            callback(nil, "OTAModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Update check

    private func checkForUpdate(serverURL: String, callback: @escaping (Any?, String?) -> Void) {
        guard let url = Self.remoteURL(from: serverURL) else {
            callback(nil, "Invalid update server URL; expected HTTP or HTTPS")
            return
        }

        let currentVersion = Self.activeBundleURL(
            defaults: defaults,
            fileManager: fileManager,
            bundleDirectory: bundleDirectory
        ) == nil ? "embedded" : (defaults.string(forKey: Self.currentVersionKey) ?? "embedded")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(currentVersion, forHTTPHeaderField: "X-Current-Version")
        request.setValue("ios", forHTTPHeaderField: "X-Platform")
        request.setValue(Bundle.main.bundleIdentifier ?? "unknown", forHTTPHeaderField: "X-App-Id")

        requestSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self, !self.isDestroyed else { return }
            if let error {
                callback(nil, "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                callback(nil, "Update server returned HTTP \(status)")
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                callback(nil, "Invalid response from update server")
                return
            }

            callback([
                "updateAvailable": json["updateAvailable"] as? Bool ?? false,
                "version": json["version"] as? String ?? "",
                "downloadUrl": json["downloadUrl"] as? String ?? "",
                "hash": json["hash"] as? String ?? "",
                "size": json["size"] as? Int ?? 0,
                "releaseNotes": json["releaseNotes"] as? String ?? "",
            ], nil)
        }.resume()
    }

    // MARK: - Download and verification

    private func downloadUpdate(
        url: String,
        expectedHash: String,
        version: String,
        callback: @escaping (Any?, String?) -> Void
    ) {
        guard let downloadURL = Self.remoteURL(from: url) else {
            callback(nil, "Invalid bundle URL; expected HTTP or HTTPS")
            return
        }
        let normalizedHash = expectedHash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isSHA256(normalizedHash) else {
            callback(nil, "downloadUpdate requires a 64-character SHA-256 hash")
            return
        }
        let normalizedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedVersion.isEmpty else {
            callback(nil, "downloadUpdate requires a non-empty version")
            return
        }

        cleanupPendingBundle(removeFile: true)

        let delegate = DownloadDelegate(bridge: bridge)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        replaceDownloadSession(with: session)

        let task = session.downloadTask(with: downloadURL) { [weak self, weak session] temporaryURL, response, error in
            defer {
                session?.finishTasksAndInvalidate()
                if let session {
                    self?.clearDownloadSession(session)
                }
            }
            guard let self, !self.isDestroyed else { return }
            if let error {
                callback(nil, "Download failed: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                callback(nil, "Bundle server returned HTTP \(status)")
                return
            }
            guard let temporaryURL else {
                callback(nil, "Download failed: no file received")
                return
            }

            do {
                let data = try Data(contentsOf: temporaryURL, options: .mappedIfSafe)
                guard !data.isEmpty, Self.isReadableJavaScript(data) else {
                    callback(nil, "Downloaded bundle is empty or is not valid UTF-8 text")
                    return
                }
                let actualHash = Self.sha256(data: data)
                guard actualHash == normalizedHash else {
                    callback(nil, "Bundle integrity check failed. Expected: \(normalizedHash), got: \(actualHash)")
                    return
                }

                try self.prepareBundleDirectory()
                let destination = self.bundleDirectory
                    .appendingPathComponent("bundle-\(normalizedHash).js", isDirectory: false)
                try data.write(to: destination, options: .atomic)

                self.defaults.set(destination.path, forKey: Self.pendingBundlePathKey)
                self.defaults.set(normalizedHash, forKey: Self.pendingBundleHashKey)
                self.defaults.set(normalizedVersion, forKey: Self.pendingVersionKey)

                callback([
                    "path": destination.path,
                    "size": data.count,
                    "version": normalizedVersion,
                ], nil)
            } catch {
                callback(nil, "Failed to save bundle: \(error.localizedDescription)")
            }
        }
        task.resume()
    }

    private func verifyBundle(callback: @escaping (Any?, String?) -> Void) {
        switch pendingBundle() {
        case .success(let bundle):
            callback([
                "verified": true,
                "version": bundle.version,
                "path": bundle.url.path,
            ], nil)
        case .failure(let error):
            callback(nil, error.localizedDescription)
        }
    }

    // MARK: - Apply and rollback

    private func applyUpdate(callback: @escaping (Any?, String?) -> Void) {
        let pending: StoredBundle
        switch pendingBundle() {
        case .success(let bundle):
            pending = bundle
        case .failure(let error):
            callback(nil, error.localizedDescription)
            return
        }

        removeSupersededPreviousBundle()
        if let currentURL = Self.activeBundleURL(
            defaults: defaults,
            fileManager: fileManager,
            bundleDirectory: bundleDirectory
        ), let currentVersion = defaults.string(forKey: Self.currentVersionKey),
           let currentHash = defaults.string(forKey: Self.bundleHashKey) {
            defaults.set(currentURL.path, forKey: Self.previousBundlePathKey)
            defaults.set(currentVersion, forKey: Self.previousVersionKey)
            defaults.set(currentHash, forKey: Self.previousBundleHashKey)
        } else {
            Self.clearPreviousState(defaults: defaults)
        }

        defaults.set(pending.url.path, forKey: Self.bundlePathKey)
        defaults.set(pending.version, forKey: Self.currentVersionKey)
        defaults.set(pending.hash, forKey: Self.bundleHashKey)
        cleanupPendingBundle(removeFile: false)

        callback(["applied": true, "version": pending.version], nil)
    }

    private func rollback(callback: @escaping (Any?, String?) -> Void) {
        cleanupPendingBundle(removeFile: true)
        let oldCurrentPath = defaults.string(forKey: Self.bundlePathKey)
        var restoredURL: URL?

        if let path = defaults.string(forKey: Self.previousBundlePathKey),
           let version = defaults.string(forKey: Self.previousVersionKey),
           let hash = defaults.string(forKey: Self.previousBundleHashKey),
           let url = Self.managedURL(path: path, bundleDirectory: bundleDirectory),
           Self.validationError(url: url, expectedHash: hash, fileManager: fileManager) == nil,
           !version.isEmpty {
            defaults.set(url.path, forKey: Self.bundlePathKey)
            defaults.set(version, forKey: Self.currentVersionKey)
            defaults.set(hash.lowercased(), forKey: Self.bundleHashKey)
            restoredURL = url
        } else {
            Self.clearActiveState(defaults: defaults)
        }
        Self.clearPreviousState(defaults: defaults)

        if let oldCurrentPath,
           oldCurrentPath != restoredURL?.path,
           let oldURL = Self.managedURL(path: oldCurrentPath, bundleDirectory: bundleDirectory) {
            try? fileManager.removeItem(at: oldURL)
        }

        callback([
            "rolledBack": true,
            "toEmbedded": restoredURL == nil,
        ], nil)
    }

    private func getCurrentVersion(callback: @escaping (Any?, String?) -> Void) {
        guard let url = Self.activeBundleURL(
            defaults: defaults,
            fileManager: fileManager,
            bundleDirectory: bundleDirectory
        ) else {
            callback([
                "version": "embedded",
                "isUsingOTA": false,
                "bundlePath": "",
            ], nil)
            return
        }

        callback([
            "version": defaults.string(forKey: Self.currentVersionKey) ?? "embedded",
            "isUsingOTA": true,
            "bundlePath": url.path,
        ], nil)
    }

    // MARK: - Startup bundle selection

    /// Resolve the active OTA bundle for application startup. Invalid, missing,
    /// unreadable, or hash-mismatched state is cleared so the host can safely
    /// fall back to its embedded bundle.
    static func activeBundleURL(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        bundleDirectory: URL? = nil
    ) -> URL? {
        let directory = bundleDirectory ?? defaultBundleDirectory(fileManager: fileManager)
        guard let path = defaults.string(forKey: bundlePathKey),
              let version = defaults.string(forKey: currentVersionKey), !version.isEmpty,
              let hash = defaults.string(forKey: bundleHashKey),
              let url = managedURL(path: path, bundleDirectory: directory),
              validationError(url: url, expectedHash: hash, fileManager: fileManager) == nil else {
            if defaults.object(forKey: bundlePathKey) != nil
                || defaults.object(forKey: currentVersionKey) != nil
                || defaults.object(forKey: bundleHashKey) != nil {
                clearActiveState(defaults: defaults)
            }
            return nil
        }
        return url
    }

    static func invalidateActiveBundle(defaults: UserDefaults = .standard) {
        clearActiveState(defaults: defaults)
    }

    // MARK: - Storage helpers

    private struct StoredBundle {
        let url: URL
        let version: String
        let hash: String
    }

    private enum BundleValidationError: LocalizedError {
        case noPendingBundle
        case invalidPath
        case invalidVersion
        case invalidHash
        case missingOrUnreadable
        case invalidText
        case hashMismatch

        var errorDescription: String? {
            switch self {
            case .noPendingBundle: return "No pending update to verify"
            case .invalidPath: return "Pending bundle path is outside the managed OTA directory"
            case .invalidVersion: return "Pending update has no version"
            case .invalidHash: return "Pending update has no valid SHA-256 hash"
            case .missingOrUnreadable: return "Pending bundle is missing or unreadable"
            case .invalidText: return "Pending bundle is empty or is not valid UTF-8 text"
            case .hashMismatch: return "Pending bundle integrity check failed"
            }
        }
    }

    private func pendingBundle() -> Result<StoredBundle, BundleValidationError> {
        guard let path = defaults.string(forKey: Self.pendingBundlePathKey),
              let hash = defaults.string(forKey: Self.pendingBundleHashKey) else {
            return .failure(.noPendingBundle)
        }
        guard let url = Self.managedURL(path: path, bundleDirectory: bundleDirectory) else {
            return .failure(.invalidPath)
        }
        guard let version = defaults.string(forKey: Self.pendingVersionKey), !version.isEmpty else {
            return .failure(.invalidVersion)
        }
        guard Self.isSHA256(hash) else {
            return .failure(.invalidHash)
        }
        if let error = Self.validationError(url: url, expectedHash: hash, fileManager: fileManager) {
            return .failure(error)
        }
        return .success(StoredBundle(url: url, version: version, hash: hash.lowercased()))
    }

    private static func validationError(
        url: URL,
        expectedHash: String,
        fileManager: FileManager
    ) -> BundleValidationError? {
        guard isSHA256(expectedHash) else { return .invalidHash }
        guard fileManager.isReadableFile(atPath: url.path),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              !data.isEmpty else {
            return .missingOrUnreadable
        }
        guard isReadableJavaScript(data) else { return .invalidText }
        return sha256(data: data) == expectedHash.lowercased() ? nil : .hashMismatch
    }

    private static func isReadableJavaScript(_ data: Data) -> Bool {
        guard let source = String(data: data, encoding: .utf8) else { return false }
        return !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func sha256(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static func isSHA256(_ hash: String) -> Bool {
        hash.range(of: "^[a-fA-F0-9]{64}$", options: .regularExpression) != nil
    }

    private static func remoteURL(from value: String) -> URL? {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host != nil else {
            return nil
        }
        return url
    }

    static func defaultBundleDirectory(fileManager: FileManager = .default) -> URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return root.appendingPathComponent("VueNativeOTA", isDirectory: true)
    }

    private static func managedURL(path: String, bundleDirectory: URL) -> URL? {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let directory = bundleDirectory.standardizedFileURL
        guard url.deletingLastPathComponent() == directory else { return nil }
        return url
    }

    private func prepareBundleDirectory() throws {
        try fileManager.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)
        var directory = bundleDirectory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
    }

    private func cleanupPendingBundle(removeFile: Bool) {
        if removeFile,
           let path = defaults.string(forKey: Self.pendingBundlePathKey),
           path != defaults.string(forKey: Self.bundlePathKey),
           path != defaults.string(forKey: Self.previousBundlePathKey),
           let url = Self.managedURL(path: path, bundleDirectory: bundleDirectory) {
            try? fileManager.removeItem(at: url)
        }
        defaults.removeObject(forKey: Self.pendingBundlePathKey)
        defaults.removeObject(forKey: Self.pendingVersionKey)
        defaults.removeObject(forKey: Self.pendingBundleHashKey)
    }

    private func removeSupersededPreviousBundle() {
        if let path = defaults.string(forKey: Self.previousBundlePathKey),
           path != defaults.string(forKey: Self.bundlePathKey),
           let url = Self.managedURL(path: path, bundleDirectory: bundleDirectory) {
            try? fileManager.removeItem(at: url)
        }
        Self.clearPreviousState(defaults: defaults)
    }

    private static func clearActiveState(defaults: UserDefaults) {
        defaults.removeObject(forKey: bundlePathKey)
        defaults.removeObject(forKey: currentVersionKey)
        defaults.removeObject(forKey: bundleHashKey)
    }

    private static func clearPreviousState(defaults: UserDefaults) {
        defaults.removeObject(forKey: previousBundlePathKey)
        defaults.removeObject(forKey: previousVersionKey)
        defaults.removeObject(forKey: previousBundleHashKey)
    }

    // MARK: - Lifecycle

    private var isDestroyed: Bool {
        sessionLock.withLock { destroyed }
    }

    private func replaceDownloadSession(with session: URLSession) {
        let previous: URLSession? = sessionLock.withLock {
            let old = downloadSession
            downloadSession = session
            return old
        }
        previous?.invalidateAndCancel()
    }

    private func clearDownloadSession(_ session: URLSession) {
        sessionLock.withLock {
            if downloadSession === session {
                downloadSession = nil
            }
        }
    }

    func destroy() {
        let activeDownload: URLSession? = sessionLock.withLock {
            guard !destroyed else { return nil }
            destroyed = true
            let session = downloadSession
            downloadSession = nil
            return session
        }
        activeDownload?.invalidateAndCancel()
        requestSession.invalidateAndCancel()
        bridge = nil
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private weak var bridge: NativeBridge?

    init(bridge: NativeBridge?) {
        self.bridge = bridge
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        let bridge = bridge
        DispatchQueue.main.async {
            bridge?.dispatchGlobalEvent("ota:downloadProgress", payload: [
                "progress": progress,
                "bytesDownloaded": totalBytesWritten,
                "totalBytes": totalBytesExpectedToWrite,
            ])
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // The download task completion handler owns persistence and verification.
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
#endif
