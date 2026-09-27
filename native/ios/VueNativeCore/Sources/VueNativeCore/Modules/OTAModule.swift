#if canImport(UIKit)
import CommonCrypto
import CryptoKit
import Foundation
import UIKit
import VueNativeShared

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

    /// Info.plist key holding the base64 DER (X.509 SubjectPublicKeyInfo) ECDSA
    /// P-256 publisher key.
    ///
    /// The publisher key MUST come from native configuration. It used to be
    /// settable from JavaScript via a `setVerifyKey` method and was never
    /// persisted natively, which meant JS was by construction the only party
    /// that could set it — there was no trust anchor at all. Any code that ran
    /// once in the JS context could install its own key, sign its own bundle,
    /// and have the ECDSA check pass.
    static let publisherKeyInfoPlistKey = "VueNativeOTAVerifyKey"

    /// Migration error returned to any JavaScript caller of `setVerifyKey`.
    /// Identical on Android so a single message documents both platforms.
    static let setVerifyKeyRejectionMessage =
        "setVerifyKey is not permitted from JavaScript; configure the OTA publisher key natively "
        + "(Info.plist VueNativeOTAVerifyKey on iOS, AndroidManifest meta-data "
        + "com.vuenative.ota.verifyKey on Android, or the host-side configurePublisherKey API)"

    /// Returned when no publisher key is configured. Verification FAILS CLOSED
    /// here: the previous behaviour accepted a hash-only bundle, which means any
    /// party able to serve bytes with a matching SHA-256 — including attacker JS
    /// that computed the hash itself — could install code.
    static let missingPublisherKeyMessage =
        "OTA update rejected: no publisher verification key is configured natively; "
        + "refusing to install an unauthenticated bundle"

    /// Error raised by the host-only key configuration entry point.
    enum PublisherKeyError: LocalizedError {
        case invalidBase64
        case invalidKey(String)

        var errorDescription: String? {
            switch self {
            case .invalidBase64:
                return "OTA publisher key is not valid base64"
            case .invalidKey(let detail):
                return "OTA publisher key is not a valid ECDSA P-256 SPKI key: \(detail)"
            }
        }
    }

    private static let hostKeyLock = NSLock()
    private static var storedHostKeyBase64: String?

    /// Host-only entry point for apps that prefer code over Info.plist.
    /// Not reachable from JavaScript.
    static func configurePublisherKey(base64SPKI: String) throws {
        guard let der = Data(base64Encoded: base64SPKI) else {
            throw PublisherKeyError.invalidBase64
        }
        do {
            _ = try P256.Signing.PublicKey(derRepresentation: der)
        } catch {
            throw PublisherKeyError.invalidKey(error.localizedDescription)
        }
        hostKeyLock.withLock { storedHostKeyBase64 = base64SPKI }
    }

    /// Test seam for the host-only configuration path.
    static func resetPublisherKeyForTesting() {
        hostKeyLock.withLock { storedHostKeyBase64 = nil }
    }

    /// Resolve the configured publisher key material: host-configured key first,
    /// then Info.plist.
    static func publisherKeyBase64(bundle: Bundle = .main) -> String? {
        if let configured = hostKeyLock.withLock({ storedHostKeyBase64 }) {
            return configured
        }
        return bundle.object(forInfoDictionaryKey: publisherKeyInfoPlistKey) as? String
    }

    private weak var bridge: NativeBridge?
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let bundleDirectory: URL
    private let sessionLock = NSLock()
    private var downloadSession: URLSession?
    private var destroyed = false

    /// ECDSA P-256 public key used to authenticate the publisher of a downloaded
    /// bundle. Resolved exclusively from native configuration — an explicit init
    /// parameter, `configurePublisherKey`, or Info.plist. Accessed from both the
    /// invoke thread and the download session's delegate queue, so the decoded
    /// key and its cache slot are guarded by `keyLock`.
    private let keyLock = NSLock()
    private let injectedKeyBase64: String?
    private var cachedKeySource: String?
    private var cachedVerifyKey: P256.Signing.PublicKey?

    /// The resolved publisher key, or `nil` when the host configured none.
    /// A `nil` result makes verification FAIL CLOSED — see `verificationError`.
    private var verifyKey: P256.Signing.PublicKey? {
        guard let source = injectedKeyBase64 ?? Self.publisherKeyBase64() else { return nil }
        return keyLock.withLock {
            if let cachedVerifyKey, cachedKeySource == source { return cachedVerifyKey }
            guard let der = Data(base64Encoded: source),
                  let key = try? P256.Signing.PublicKey(derRepresentation: der) else {
                #if DEBUG
                NSLog(
                    "[VueNative OTA] Configured publisher key could not be decoded; "
                    + "updates will be rejected until Info.plist '%@' is fixed",
                    Self.publisherKeyInfoPlistKey
                )
                #endif
                cachedKeySource = nil
                cachedVerifyKey = nil
                return nil
            }
            cachedKeySource = source
            cachedVerifyKey = key
            return key
        }
    }

    init(
        bridge: NativeBridge,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        bundleDirectory: URL? = nil,
        publisherKeyBase64: String? = nil
    ) {
        self.bridge = bridge
        self.defaults = defaults
        self.fileManager = fileManager
        self.bundleDirectory = bundleDirectory ?? Self.defaultBundleDirectory(fileManager: fileManager)
        // An explicitly injected key wins over `configurePublisherKey` and
        // Info.plist so tests and hosts that build the module directly are
        // deterministic regardless of process-global state.
        self.injectedKeyBase64 = publisherKeyBase64 ?? Self.publisherKeyBase64()
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
            // The 4th argument carries the optional base64(DER ECDSA-P256-SHA256)
            // signature over the bundle bytes, used when a verify key is configured.
            let signature = args.count > 3 ? args[3] as? String : nil
            downloadUpdate(
                url: url,
                expectedHash: expectedHash,
                version: version,
                signature: signature,
                callback: callback
            )

        case "setVerifyKey":
            // Retained in the dispatch table purely so callers get an actionable
            // migration error instead of "Unknown method". It never installs a
            // key: a key settable by the code it authenticates is not a trust
            // anchor. The key must come from Info.plist or host Swift code.
            #if DEBUG
            NSLog(
                "[VueNative OTA] Ignoring setVerifyKey from JavaScript. Configure the publisher key "
                + "natively via Info.plist '%@' or OTAModule.configurePublisherKey(base64SPKI:).",
                Self.publisherKeyInfoPlistKey
            )
            #endif
            callback(nil, Self.setVerifyKeyRejectionMessage)

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
            callback(nil, "Invalid update server URL; expected HTTPS")
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

        // Route the manifest request through the pinning-aware session so any
        // configured certificate pins apply to the OTA channel.
        CertificatePinning.shared.requestSession.dataTask(with: request) { [weak self] data, response, error in
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
        signature: String?,
        callback: @escaping (Any?, String?) -> Void
    ) {
        guard let downloadURL = Self.remoteURL(from: url) else {
            callback(nil, "Invalid bundle URL; expected HTTPS")
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

        // Anti-downgrade, checked before spending any bandwidth. Without this an
        // attacker who can serve bytes could reinstall an older, vulnerable
        // bundle whose signature is still valid.
        if let installed = installedVersion(),
           !Self.isStrictlyNewer(candidate: normalizedVersion, current: installed) {
            callback(nil, Self.downgradeMessage(candidate: normalizedVersion, current: installed))
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
                // Integrity (SHA-256) plus, when a verify key is configured,
                // publisher authentication (ECDSA P-256 signature).
                if let verificationError = self.verificationError(
                    for: data,
                    expectedHash: normalizedHash,
                    signature: signature
                ) {
                    callback(nil, verificationError)
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

    // MARK: - Publisher verification (ECDSA P-256)

    /// Verify downloaded bundle bytes: SHA-256 integrity, then the ECDSA P-256
    /// (SHA-256, DER) publisher signature.
    ///
    /// CryptoKit's `isValidSignature(_:for:)` hashes the supplied data internally
    /// (SHA-256 for P-256), so the signature is verified against the raw bundle
    /// bytes, not a pre-computed digest. The signing side must likewise sign the
    /// raw bytes (`signature(for: data)`).
    ///
    /// Publisher authentication is MANDATORY. When the host has not configured a
    /// key this returns ``missingPublisherKeyMessage`` instead of accepting the
    /// bundle on its hash alone — integrity without authentication only proves
    /// the bytes were not corrupted in transit, not who produced them.
    ///
    /// - Returns: `nil` when the bundle passes every check, or a rejection message.
    func verificationError(for data: Data, expectedHash: String, signature: String?) -> String? {
        guard !data.isEmpty, Self.isReadableJavaScript(data) else {
            return "Downloaded bundle is empty or is not valid UTF-8 text"
        }
        let actualHash = Self.sha256(data: data)
        guard actualHash == expectedHash.lowercased() else {
            return "Bundle integrity check failed. Expected: \(expectedHash.lowercased()), got: \(actualHash)"
        }

        guard let verifyKey = self.verifyKey else {
            return Self.missingPublisherKeyMessage
        }
        guard let signature, !signature.isEmpty else {
            return "OTA update rejected: signature required when a verify key is configured"
        }
        guard let signatureData = Data(base64Encoded: signature),
              let ecdsaSignature = try? P256.Signing.ECDSASignature(derRepresentation: signatureData),
              verifyKey.isValidSignature(ecdsaSignature, for: data) else {
            return "OTA update rejected: signature verification failed"
        }
        return nil
    }

    // MARK: - Version ordering (anti-downgrade)

    /// Compare two dotted version strings.
    ///
    /// Segments that are all digits on both sides compare numerically (so
    /// `1.10.0` > `1.9.0`); any other pair compares lexically. A missing segment
    /// counts as `0` numerically and as the empty string lexically.
    ///
    /// Semver pre-release ordering is deliberately NOT implemented: `1.0.0-a`
    /// and `1.0.0-b` compare lexically as whole segments. Versions used for OTA
    /// gating should be plain dotted numerics.
    static func compareVersions(_ lhs: String, _ rhs: String) -> Int {
        let left = lhs.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let right = rhs.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        for index in 0..<max(left.count, right.count) {
            // A missing segment counts as "0", not as the empty string, so
            // `2.0.1` is correctly newer than `2.0` and `2.0` equals `2.0.0`.
            let leftSegment = index < left.count ? left[index] : "0"
            let rightSegment = index < right.count ? right[index] : "0"
            let leftDigits = Self.isNumericSegment(leftSegment)
            let rightDigits = Self.isNumericSegment(rightSegment)
            if leftDigits && rightDigits {
                let leftValue = Int(leftSegment) ?? 0
                let rightValue = Int(rightSegment) ?? 0
                if leftValue != rightValue { return leftValue < rightValue ? -1 : 1 }
            } else {
                let leftText = leftDigits ? "" : leftSegment
                let rightText = rightDigits ? "" : rightSegment
                if leftText != rightText { return leftText < rightText ? -1 : 1 }
            }
        }
        return 0
    }

    /// `true` when `candidate` is strictly newer than the installed version.
    /// A `nil` current version means the app is running its embedded bundle, so
    /// any candidate is newer.
    static func isStrictlyNewer(candidate: String, current: String?) -> Bool {
        guard let current, !current.isEmpty else { return true }
        return compareVersions(candidate, current) > 0
    }

    /// ASCII-only digit test. `Character.isNumber` also accepts non-ASCII digits
    /// that `Int(_:)` cannot parse, which would silently collapse to 0.
    private static func isNumericSegment(_ segment: String) -> Bool {
        !segment.isEmpty && segment.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Rejection message for a downgrade attempt.
    static func downgradeMessage(candidate: String, current: String) -> String {
        "OTA update rejected: version '\(candidate)' is not newer than the installed version '\(current)'"
    }

    /// The version of the bundle that will actually run at next launch, or `nil`
    /// when the app is on its embedded bundle.
    private func installedVersion() -> String? {
        guard Self.activeBundleURL(
            defaults: defaults,
            fileManager: fileManager,
            bundleDirectory: bundleDirectory
        ) != nil else { return nil }
        let version = defaults.string(forKey: Self.currentVersionKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let version, !version.isEmpty else { return nil }
        return version
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

        // Authoritative anti-downgrade gate. `downloadUpdate` checks the same
        // rule, but the pending state lives in `UserDefaults` and could have
        // been staged by an older build or written directly, so re-check here.
        if let installed = installedVersion(),
           !Self.isStrictlyNewer(candidate: pending.version, current: installed) {
            callback(nil, Self.downgradeMessage(candidate: pending.version, current: installed))
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
              scheme == "https",
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
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // The download session owns its own delegate for progress reporting, so
        // it cannot reuse the pinning session directly. Forward TLS trust
        // evaluation to the shared pinning delegate instead, ensuring configured
        // certificate pins apply to the channel whose payload is executed as code.
        CertificatePinning.shared.urlSession(session, didReceive: challenge, completionHandler: completionHandler)
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
