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

    // MARK: - Roots

    /// Canonicalised sandbox roots: documents, caches, application support and
    /// the temporary directory. Computed per call because the container path
    /// embeds a per-install UUID and caching it would make the class hold
    /// mutable state across threads for no benefit.
    public func allowedRoots(fileManager: FileManager = .default) -> [URL] {
        let searchPaths: [FileManager.SearchPathDirectory] = [
            .documentDirectory,
            .cachesDirectory,
            .applicationSupportDirectory,
        ]
        var roots: [URL] = []
        for directory in searchPaths {
            if let url = fileManager.urls(for: directory, in: .userDomainMask).first {
                roots.append(canonicalise(url, fileManager: fileManager))
            }
        }
        roots.append(canonicalise(fileManager.temporaryDirectory, fileManager: fileManager))
        return roots
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

    private func documentsRoot(fileManager: FileManager) -> URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private func reservedOTADirectory(fileManager: FileManager) -> URL? {
        guard let support = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        return canonicalise(
            support.appendingPathComponent(Self.reservedOTADirectoryName, isDirectory: true),
            fileManager: fileManager
        )
    }

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
