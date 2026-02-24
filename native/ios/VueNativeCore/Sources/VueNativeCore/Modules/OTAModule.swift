#if canImport(UIKit)
import UIKit
import CommonCrypto

/// Native module for Over-The-Air (OTA) JS bundle updates.
///
/// Methods:
///   - checkForUpdate(serverUrl) — check for available updates
///   - downloadUpdate(url, hash) — download a new bundle and verify integrity
///   - applyUpdate() — swap to downloaded bundle on next launch
///   - rollback() — revert to the embedded bundle
///   - getCurrentVersion() — get current bundle version info
///
/// Events:
///   - ota:downloadProgress — payload: { progress: 0.0-1.0, bytesDownloaded, totalBytes }
final class OTAModule: NativeModule {
    var moduleName: String { "OTA" }

    private let defaults = UserDefaults.standard
    private let keyPrefix = "VueNative.OTA."

    // UserDefaults keys
    private var currentVersionKey: String { keyPrefix + "currentVersion" }
    private var bundlePathKey: String { keyPrefix + "bundlePath" }
    private var previousBundlePathKey: String { keyPrefix + "previousBundlePath" }
    private var previousVersionKey: String { keyPrefix + "previousVersion" }

    private weak var bridge: NativeBridge?

    init(bridge: NativeBridge) {
        self.bridge = bridge
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "checkForUpdate":
            guard let serverUrl = args.first as? String else {
                callback(nil, "checkForUpdate: missing serverUrl")
                return
            }
            checkForUpdate(serverUrl: serverUrl, callback: callback)

        case "downloadUpdate":
            guard args.count >= 1,
                  let url = args[0] as? String else {
                callback(nil, "downloadUpdate: missing url")
                return
            }
            let expectedHash = args.count >= 2 ? args[1] as? String : nil
            downloadUpdate(url: url, expectedHash: expectedHash, callback: callback)

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

    // MARK: - Check for update

    private func checkForUpdate(serverUrl: String, callback: @escaping (Any?, String?) -> Void) {
        guard let url = URL(string: serverUrl) else {
            callback(nil, "Invalid server URL")
            return
        }

        let currentVersion = defaults.string(forKey: currentVersionKey) ?? "0"

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(currentVersion, forHTTPHeaderField: "X-Current-Version")
        request.setValue("ios", forHTTPHeaderField: "X-Platform")
        request.setValue(Bundle.main.bundleIdentifier ?? "unknown", forHTTPHeaderField: "X-App-Id")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                callback(nil, "Network error: \(error.localizedDescription)")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                callback(nil, "Invalid response from update server")
                return
            }

            let updateAvailable = json["updateAvailable"] as? Bool ?? false
            let result: [String: Any] = [
                "updateAvailable": updateAvailable,
                "version": json["version"] as? String ?? "",
                "downloadUrl": json["downloadUrl"] as? String ?? "",
                "hash": json["hash"] as? String ?? "",
                "size": json["size"] as? Int ?? 0,
                "releaseNotes": json["releaseNotes"] as? String ?? "",
            ]
            callback(result, nil)
        }.resume()
    }

    // MARK: - Download update

    private func downloadUpdate(url: String, expectedHash: String?, callback: @escaping (Any?, String?) -> Void) {
        guard let downloadUrl = URL(string: url) else {
            callback(nil, "Invalid download URL")
            return
        }

        let session = URLSession(configuration: .default, delegate: DownloadDelegate(bridge: bridge), delegateQueue: nil)
        let task = session.downloadTask(with: downloadUrl) { [weak self] tempUrl, response, error in
            guard let self = self else { return }

            if let error = error {
                callback(nil, "Download failed: \(error.localizedDescription)")
                return
            }

            guard let tempUrl = tempUrl else {
                callback(nil, "Download failed: no file received")
                return
            }

            do {
                // Read downloaded data
                let data = try Data(contentsOf: tempUrl)

                // Verify hash if provided
                if let expectedHash = expectedHash, !expectedHash.isEmpty {
                    let actualHash = self.sha256(data: data)
                    if actualHash.lowercased() != expectedHash.lowercased() {
                        callback(nil, "Bundle integrity check failed. Expected: \(expectedHash), got: \(actualHash)")
                        return
                    }
                }

                // Save to Documents directory
                let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let bundleDir = docsDir.appendingPathComponent("VueNativeOTA", isDirectory: true)
                try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)

                let bundlePath = bundleDir.appendingPathComponent("bundle.js")

                // Remove old pending download if exists
                if FileManager.default.fileExists(atPath: bundlePath.path) {
                    try FileManager.default.removeItem(at: bundlePath)
                }

                try data.write(to: bundlePath)

                // Store the path for applyUpdate
                self.defaults.set(bundlePath.path, forKey: self.keyPrefix + "pendingBundlePath")

                callback(["path": bundlePath.path, "size": data.count], nil)
            } catch {
                callback(nil, "Failed to save bundle: \(error.localizedDescription)")
            }
        }
        task.resume()
    }

    // MARK: - Apply update

    private func applyUpdate(callback: @escaping (Any?, String?) -> Void) {
        guard let pendingPath = defaults.string(forKey: keyPrefix + "pendingBundlePath"),
              FileManager.default.fileExists(atPath: pendingPath) else {
            callback(nil, "No pending update to apply")
            return
        }

        // Save current bundle path for rollback
        if let currentPath = defaults.string(forKey: bundlePathKey) {
            defaults.set(currentPath, forKey: previousBundlePathKey)
        }
        if let currentVersion = defaults.string(forKey: currentVersionKey) {
            defaults.set(currentVersion, forKey: previousVersionKey)
        }

        // Set the new bundle as current
        defaults.set(pendingPath, forKey: bundlePathKey)
        defaults.removeObject(forKey: keyPrefix + "pendingBundlePath")

        // Increment version tracker
        let currentVersion = defaults.integer(forKey: currentVersionKey)
        defaults.set(currentVersion + 1, forKey: currentVersionKey)

        callback(["applied": true], nil)
    }

    // MARK: - Rollback

    private func rollback(callback: @escaping (Any?, String?) -> Void) {
        guard let previousPath = defaults.string(forKey: previousBundlePathKey) else {
            // Rollback to embedded bundle
            defaults.removeObject(forKey: bundlePathKey)
            if let prevVersion = defaults.string(forKey: previousVersionKey) {
                defaults.set(prevVersion, forKey: currentVersionKey)
            } else {
                defaults.removeObject(forKey: currentVersionKey)
            }
            callback(["rolledBack": true, "toEmbedded": true], nil)
            return
        }

        defaults.set(previousPath, forKey: bundlePathKey)
        if let prevVersion = defaults.string(forKey: previousVersionKey) {
            defaults.set(prevVersion, forKey: currentVersionKey)
        }
        defaults.removeObject(forKey: previousBundlePathKey)
        defaults.removeObject(forKey: previousVersionKey)

        callback(["rolledBack": true, "toEmbedded": false], nil)
    }

    // MARK: - Get current version

    private func getCurrentVersion(callback: @escaping (Any?, String?) -> Void) {
        let version = defaults.string(forKey: currentVersionKey) ?? "embedded"
        let bundlePath = defaults.string(forKey: bundlePathKey)
        let isUsingOTA = bundlePath != nil && FileManager.default.fileExists(atPath: bundlePath!)

        callback([
            "version": version,
            "isUsingOTA": isUsingOTA,
            "bundlePath": bundlePath ?? "",
        ], nil)
    }

    // MARK: - SHA-256

    private func sha256(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}

// MARK: - Download delegate for progress reporting

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private weak var bridge: NativeBridge?

    init(bridge: NativeBridge?) {
        self.bridge = bridge
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            progress = 0
        }

        let bridge = bridge
        DispatchQueue.main.async {
            bridge?.dispatchGlobalEvent("ota:downloadProgress", payload: [
                "progress": progress,
                "bytesDownloaded": totalBytesWritten,
                "totalBytes": totalBytesExpectedToWrite,
            ])
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Handled in the completion handler of the download task
    }
}
#endif
