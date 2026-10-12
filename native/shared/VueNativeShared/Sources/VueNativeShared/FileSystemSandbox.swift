import Foundation

/// Errors raised when a JavaScript-supplied path cannot be safely resolved.
public enum FileSystemSandboxError: LocalizedError {
    case emptyPath
    case reserved(String)
    case outsideSandbox(String)

    public var errorDescription: String? {
        switch self {
        case .emptyPath:
            return "FileSystem: path is empty"
        case .reserved(let path):
            return "FileSystem: '\(path)' is a reserved Vue Native directory"
        case .outsideSandbox(let path):
            return "FileSystem: path escapes the app sandbox: '\(path)'"
        }
    }
}

/// Confinement authority for every path handed to `FileSystemModule` by JavaScript.
///
/// ## Why this exists
///
/// The JS bundle is untrusted in the worst case: a malicious OTA update, a
/// compromised npm dependency, or a message injected through `VWebView` all get
/// to execute once with full native-module privileges. Before this guard,
/// `FileSystem` accepted arbitrary absolute paths with no canonicalisation, no
/// symlink resolution and no root confinement, so attacker-controlled JS could
/// read, write and delete anywhere the app UID reaches.
///
/// The concrete escalation on iOS was writing
/// `<App Support>/VueNativeOTA/bundle-<sha>.js`, which — combined with the
/// matching `UserDefaults` keys — gave persistent code execution at the next
/// launch and bypassed OTA signature verification entirely. Confinement alone
/// does not close that, because the OTA store legitimately lives under
/// Application Support, so `.reserved` denies it explicitly as well.
///
/// ## Rules
///
/// 1. Paths are trimmed; an empty path is rejected.
/// 2. `~` is expanded; a relative path is resolved against the documents root.
/// 3. The result is canonicalised with `resolvingSymlinksInPath()`, which both
///    collapses `..` segments and resolves symlinks for the existing prefix.
///    A symlink that points outside the sandbox therefore resolves to a path
///    outside it and is rejected by step 5 — it cannot be used to escape.
/// 4. Reserved framework directories are denied.
/// 5. The canonical path must be inside one of the resolved sandbox roots.
///
/// ## Roots on macOS
///
/// The macOS scaffold does not enable the App Sandbox, so `~/Documents`,
/// `~/Library/Caches`, `~/Library/Application Support` and `$TMPDIR` are shared by
/// every app of the user. An unsandboxed process therefore gets per-app roots
/// instead: `~/Library/Application Support/<id>`, `~/Library/Caches/<id>`,
/// `$TMPDIR/<id>`, and `<id>/Documents` inside Application Support. `<id>` is the
/// bundle identifier, or the process name when there is none. A host that needs
/// the real `~/Documents` sets ``allowsUserDocumentsDirectory``. Sandboxed builds
/// and iOS keep the system directories.
///
/// Rejections are always surfaced as errors. Nothing here falls back silently to
/// "use the path anyway".
public final class FileSystemSandbox {

    /// Process-wide default used by `FileSystemModule`.
    public static let shared = FileSystemSandbox()

    /// Default byte cap for `FileSystem.downloadFile` (25 MiB).
    public static let defaultMaxDownloadBytes = 25 * 1024 * 1024

    private let configLock = NSLock()
    private var storedMaxDownloadBytes: Int
    private var storedAllowInsecureDownloads: Bool
    private var storedAllowsUserDocumentsDirectory = false

    /// Directory name of the OTA bundle store, relative to Application Support.
    static let reservedOTADirectoryName = "VueNativeOTA"

    public init(
        maxDownloadBytes: Int = FileSystemSandbox.defaultMaxDownloadBytes,
        allowInsecureDownloads: Bool = false
    ) {
        storedMaxDownloadBytes = maxDownloadBytes
        storedAllowInsecureDownloads = allowInsecureDownloads
    }

    // MARK: - Host configuration (never settable from JavaScript)

    /// Upper bound on bytes `downloadFile` will accept. Host-configurable only;
    /// exposing this to JS would let a compromised bundle exhaust memory or disk.
    public var maxDownloadBytes: Int {
        get { configLock.withLock { storedMaxDownloadBytes } }
        set { configLock.withLock { storedMaxDownloadBytes = max(0, newValue) } }
    }

    /// When `false` (the default) `downloadFile` requires HTTPS. Loopback hosts
    /// are always permitted so local dev servers and test fixtures keep working.
    public var allowInsecureDownloads: Bool {
        get { configLock.withLock { storedAllowInsecureDownloads } }
        set { configLock.withLock { storedAllowInsecureDownloads = newValue } }
    }

    /// macOS builds without the App Sandbox only. When `true` the documents root
    /// is the real `~/Documents`, which every app of the user shares; when `false`
    /// (the default) it is the app's own `Application Support/<id>/Documents`.
    /// Ignored on iOS and in sandboxed builds. Host-configurable only.
    public var allowsUserDocumentsDirectory: Bool {
        get { configLock.withLock { storedAllowsUserDocumentsDirectory } }
        set { configLock.withLock { storedAllowsUserDocumentsDirectory = newValue } }
    }

    // MARK: - Roots

    /// Canonicalised sandbox roots: documents, caches, application support and
    /// the temporary directory. Computed per call because the container path
    /// embeds a per-install UUID and caching it would make the class hold
    /// mutable state across threads for no benefit.
    public func allowedRoots(fileManager: FileManager = .default) -> [URL] {
        var roots: [URL] = []
        if let documents = documentsRoot(fileManager: fileManager) {
            roots.append(documents)
        }
        if let caches = cachesRoot(fileManager: fileManager) {
            roots.append(caches)
        }
        if let support = applicationSupportRoot(fileManager: fileManager) {
            roots.append(support)
        }
        roots.append(temporaryRoot(fileManager: fileManager))
        return roots
    }

    /// Documents root: the anchor for relative paths and the directory that
    /// `FileSystem.getDocumentsPath` reports. See the type documentation for the
    /// unsandboxed macOS layout.
    func documentsRoot(fileManager: FileManager = .default) -> URL? {
        #if os(macOS)
        if !Self.isAppSandboxed {
            if allowsUserDocumentsDirectory {
                return systemDirectory(.documentDirectory, fileManager: fileManager)
            }
            guard let support = applicationSupportRoot(fileManager: fileManager) else { return nil }
            return ownedDirectory(
                support.appendingPathComponent("Documents", isDirectory: true),
                fileManager: fileManager
            )
        }
        #endif
        return systemDirectory(.documentDirectory, fileManager: fileManager)
    }

    /// Caches root, reported by `FileSystem.getCachesPath`.
    func cachesRoot(fileManager: FileManager = .default) -> URL? {
        appDirectory(.cachesDirectory, fileManager: fileManager)
    }

    /// Application Support root. The reserved OTA store lives inside it.
    func applicationSupportRoot(fileManager: FileManager = .default) -> URL? {
        appDirectory(.applicationSupportDirectory, fileManager: fileManager)
    }

    /// Temporary root. Always available. Public so framework modules that write a
    /// scratch file and hand its path to JavaScript (recordings, captured photos)
    /// put it where `useFileSystem` can read it back: on an unsandboxed macOS host
    /// the bare temporary directory is outside the sandbox.
    public func temporaryRoot(fileManager: FileManager = .default) -> URL {
        #if os(macOS)
        if !Self.isAppSandboxed {
            return ownedDirectory(
                fileManager.temporaryDirectory.appendingPathComponent(
                    Self.unsandboxedAppIdentifier,
                    isDirectory: true
                ),
                fileManager: fileManager
            )
        }
        #endif
        return canonicalise(fileManager.temporaryDirectory, fileManager: fileManager)
    }

    /// Canonical location of the reserved OTA store.
    func reservedOTADirectory(fileManager: FileManager = .default) -> URL? {
        guard let support = applicationSupportRoot(fileManager: fileManager) else { return nil }
        return canonicalise(
            support.appendingPathComponent(Self.reservedOTADirectoryName, isDirectory: true),
            fileManager: fileManager
        )
    }

    // MARK: - Resolution

    /// Resolve and confine a JavaScript-supplied path.
    ///
    /// - Throws: `FileSystemSandboxError` when the path is empty, reserved, or
    ///   resolves outside the app sandbox.
    public func resolve(_ path: String, fileManager: FileManager = .default) throws -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FileSystemSandboxError.emptyPath }

        let roots = allowedRoots(fileManager: fileManager)

        let expanded = (trimmed as NSString).expandingTildeInPath
        // A relative path is meaningless without an anchor; anchor it at the
        // documents root rather than the process working directory, which on a
        // device is `/` and would make every relative path escape.
        let anchored: String
        if expanded.hasPrefix("/") {
            anchored = expanded
        } else if let documents = documentsRoot(fileManager: fileManager) {
            anchored = documents.appendingPathComponent(expanded).path
        } else {
            throw FileSystemSandboxError.outsideSandbox(trimmed)
        }

        let resolved = canonicalise(URL(fileURLWithPath: anchored), fileManager: fileManager)
        let resolvedPath = resolved.path

        if let reserved = reservedOTADirectory(fileManager: fileManager),
           reserved.path == resolvedPath
               || resolvedPath.hasPrefix(reserved.path + "/") {
            throw FileSystemSandboxError.reserved(trimmed)
        }

        for root in roots where root.path == resolvedPath || resolvedPath.hasPrefix(root.path + "/") {
            return resolved
        }
        throw FileSystemSandboxError.outsideSandbox(trimmed)
    }

    /// `true` when `path` resolves inside the sandbox and is not reserved.
    public func isAllowed(_ path: String, fileManager: FileManager = .default) -> Bool {
        (try? resolve(path, fileManager: fileManager)) != nil
    }

    /// `true` when the resolved path IS one of the sandbox roots themselves.
    /// Deleting a root would remove the whole documents/caches tree in one call.
    public func isSandboxRoot(_ url: URL, fileManager: FileManager = .default) -> Bool {
        let path = canonicalise(url, fileManager: fileManager).path
        return allowedRoots(fileManager: fileManager).contains { $0.path == path }
    }

    /// `true` when the resolved path is a strict ancestor of the reserved OTA
    /// directory. Replacing or moving such a directory would remove the OTA store,
    /// and copying it would expose the bundles stored there.
    public func isAncestorOfReserved(_ url: URL, fileManager: FileManager = .default) -> Bool {
        guard let reserved = reservedOTADirectory(fileManager: fileManager) else { return false }
        let path = canonicalise(url, fileManager: fileManager).path
        return reserved.path.hasPrefix(path + "/")
    }

    // MARK: - Downloads

    /// HTTPS is required unless the host opted into insecure downloads.
    /// Loopback hosts are always permitted: that traffic never leaves the
    /// machine, so local dev servers and test fixtures keep working without
    /// weakening production.
    public func isSecureDownload(_ url: URL) -> Bool {
        if allowInsecureDownloads { return true }
        if url.scheme?.lowercased() == "https" { return true }
        guard let host = url.host?.lowercased() else { return false }
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    // MARK: - Helpers

    /// The system directory itself, canonicalised. Used directly on iOS and by
    /// sandboxed macOS builds, where the directory already belongs to this app.
    private func systemDirectory(
        _ searchPath: FileManager.SearchPathDirectory,
        fileManager: FileManager
    ) -> URL? {
        guard let url = fileManager.urls(for: searchPath, in: .userDomainMask).first else {
            return nil
        }
        return canonicalise(url, fileManager: fileManager)
    }

    /// A system directory the app owns. Unsandboxed macOS shares these directories
    /// between every app of the user, so the app gets `<directory>/<app id>`.
    private func appDirectory(
        _ searchPath: FileManager.SearchPathDirectory,
        fileManager: FileManager
    ) -> URL? {
        #if os(macOS)
        if !Self.isAppSandboxed {
            guard let base = fileManager.urls(for: searchPath, in: .userDomainMask).first else {
                return nil
            }
            return ownedDirectory(
                base.appendingPathComponent(Self.unsandboxedAppIdentifier, isDirectory: true),
                fileManager: fileManager
            )
        }
        #endif
        return systemDirectory(searchPath, fileManager: fileManager)
    }

    #if os(macOS)
    /// `true` when the process runs inside the App Sandbox, where the system
    /// directories already belong to this app alone.
    static var isAppSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    /// Folder name for this app under the shared macOS directories. The bundle
    /// identifier is used when there is one; under `swift test` the bundle is
    /// usually absent, so the process name stands in.
    static var unsandboxedAppIdentifier: String {
        if let identifier = Bundle.main.bundleIdentifier, !identifier.isEmpty {
            return identifier
        }
        let processName = ProcessInfo.processInfo.processName
        return processName.isEmpty ? "VueNativeApp" : processName
    }

    /// Creates `url` when it is missing, then returns its canonical form.
    private func ownedDirectory(_ url: URL, fileManager: FileManager) -> URL {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return canonicalise(url, fileManager: fileManager)
    }
    #endif

    /// Collapse `..` and resolve symlinks so the result can be compared against
    /// the canonicalised roots by plain string prefix.
    ///
    /// `resolvingSymlinksInPath()` is documented to be unreliable for paths that
    /// do not exist yet — exactly the case for `writeFile` and `mkdir` targets.
    /// Walk up to the deepest existing ancestor, resolve symlinks there, then
    /// re-append the non-existent tail. A symlinked ancestor therefore still
    /// resolves to its real location and cannot be used to escape the sandbox.
    private func canonicalise(_ url: URL, fileManager: FileManager) -> URL {
        let standardized = url.standardizedFileURL
        var existing = standardized
        var tail: [String] = []
        while !fileManager.fileExists(atPath: existing.path) {
            let parent = existing.deletingLastPathComponent()
            if parent.path == existing.path { break }
            tail.insert(existing.lastPathComponent, at: 0)
            existing = parent
        }
        var resolved = existing.resolvingSymlinksInPath()
        for component in tail {
            resolved = resolved.appendingPathComponent(component)
        }
        return resolved.standardizedFileURL
    }
}
