import Foundation

/// Native module providing file system access.
///
/// Methods:
///   - readFile(path: String, encoding: String?) -> String
///   - writeFile(path: String, content: String, encoding: String?)
///   - deleteFile(path: String)
///   - exists(path: String) -> Bool
///   - listDirectory(path: String) -> [String]
///   - downloadFile(url: String, destPath: String) -> String
///   - getDocumentsPath() -> String
///   - getCachesPath() -> String
///   - stat(path: String) -> { size, isDirectory, modified }
///   - mkdir(path: String)
///   - copyFile(srcPath: String, destPath: String)
///   - moveFile(srcPath: String, destPath: String)
///
/// ## Path confinement
///
/// Every path argument is resolved through ``FileSystemSandbox`` before any I/O.
/// The JavaScript bundle is untrusted in the worst case — a malicious OTA update
/// or a compromised dependency gets to call these methods with full app-UID
/// privileges — so an arbitrary absolute path from JS must never reach
/// `FileManager`. Resolution canonicalises the path, resolves symlinks, and
/// rejects anything that is not inside the app's documents, caches, application
/// support or temporary directory. Rejections are surfaced as errors; there is
/// no silent fallback to the raw path.
public final class FileSystemModule: NativeModule {
    public let moduleName = "FileSystem"

    private let fileManager: FileManager
    private let sandbox: FileSystemSandbox

    private let sessionLock = NSLock()
    private var downloadSessions: [URLSession] = []
    private var destroyed = false

    public init(
        fileManager: FileManager = .default,
        sandbox: FileSystemSandbox = .shared
    ) {
        self.fileManager = fileManager
        self.sandbox = sandbox
    }

    public func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            switch method {
            case "readFile":
                guard let path = args.first as? String else {
                    callback(nil, "readFile: missing path")
                    return
                }
                guard let url = self.resolve(path, callback: callback) else { return }
                let encoding = (args.count > 1 ? args[1] as? String : nil) ?? "utf8"
                guard self.fileManager.fileExists(atPath: url.path) else {
                    callback(nil, "readFile: file not found at \(url.path)")
                    return
                }
                guard let data = self.fileManager.contents(atPath: url.path) else {
                    callback(nil, "readFile: could not read file at \(url.path)")
                    return
                }
                if encoding == "base64" {
                    callback(data.base64EncodedString(), nil)
                } else {
                    guard let text = String(data: data, encoding: .utf8) else {
                        callback(nil, "readFile: file is not valid UTF-8")
                        return
                    }
                    callback(text, nil)
                }

            case "writeFile":
                guard args.count >= 2,
                      let path = args[0] as? String,
                      let content = args[1] as? String else {
                    callback(nil, "writeFile: missing path or content")
                    return
                }
                guard let url = self.resolve(path, callback: callback) else { return }
                let encoding = (args.count > 2 ? args[2] as? String : nil) ?? "utf8"
                let data: Data?
                if encoding == "base64" {
                    data = Data(base64Encoded: content)
                } else {
                    data = content.data(using: .utf8)
                }
                guard let fileData = data else {
                    callback(nil, "writeFile: could not encode content")
                    return
                }
                if let error = self.ensureParentDirectory(of: url) {
                    callback(nil, "writeFile: \(error)")
                    return
                }
                guard self.fileManager.createFile(atPath: url.path, contents: fileData) else {
                    callback(nil, "writeFile: could not write file at \(url.path)")
                    return
                }
                callback(nil, nil)

            case "deleteFile":
                guard let path = args.first as? String else {
                    callback(nil, "deleteFile: missing path")
                    return
                }
                guard let url = self.resolve(path, callback: callback) else { return }
                guard !self.sandbox.isSandboxRoot(url, fileManager: self.fileManager) else {
                    callback(nil, "FileSystem: refusing to delete a sandbox root directory")
                    return
                }
                guard self.fileManager.fileExists(atPath: url.path) else {
                    callback(nil, "deleteFile: file not found at \(url.path)")
                    return
                }
                do {
                    try self.fileManager.removeItem(atPath: url.path)
                    callback(nil, nil)
                } catch {
                    callback(nil, "deleteFile: \(error.localizedDescription)")
                }

            case "exists":
                guard let path = args.first as? String else {
                    callback(nil, "exists: missing path")
                    return
                }
                guard let url = self.resolve(path, callback: callback) else { return }
                callback(self.fileManager.fileExists(atPath: url.path), nil)

            case "listDirectory":
                guard let path = args.first as? String else {
                    callback(nil, "listDirectory: missing path")
                    return
                }
                guard let url = self.resolve(path, callback: callback) else { return }
                do {
                    let contents = try self.fileManager.contentsOfDirectory(atPath: url.path)
                    callback(contents, nil)
                } catch {
                    callback(nil, "listDirectory: \(error.localizedDescription)")
                }

            case "downloadFile":
                guard args.count >= 2,
                      let urlString = args[0] as? String,
                      let destPath = args[1] as? String else {
                    callback(nil, "downloadFile: missing url or destPath")
                    return
                }
                guard let url = URL(string: urlString), url.scheme != nil else {
                    callback(nil, "downloadFile: invalid URL")
                    return
                }
                guard self.sandbox.isSecureDownload(url) else {
                    callback(nil, "downloadFile: refusing non-HTTPS URL: \(urlString)")
                    return
                }
                guard let destination = self.resolve(destPath, callback: callback) else { return }
                self.downloadFile(from: url, to: destination, callback: callback)

            case "getDocumentsPath":
                let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                callback(paths.first, nil)

            case "getCachesPath":
                let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
                callback(paths.first, nil)

            case "stat":
                guard let path = args.first as? String else {
                    callback(nil, "stat: missing path")
                    return
                }
                guard let url = self.resolve(path, callback: callback) else { return }
                do {
                    let attrs = try self.fileManager.attributesOfItem(atPath: url.path)
                    let size = (attrs[.size] as? Int) ?? 0
                    let isDir = (attrs[.type] as? FileAttributeType) == .typeDirectory
                    let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                    callback([
                        "size": size,
                        "isDirectory": isDir,
                        "modified": modified * 1000 // milliseconds for JS
                    ] as [String: Any], nil)
                } catch {
                    callback(nil, "stat: \(error.localizedDescription)")
                }

            case "mkdir":
                guard let path = args.first as? String else {
                    callback(nil, "mkdir: missing path")
                    return
                }
                guard let url = self.resolve(path, callback: callback) else { return }
                do {
                    try self.fileManager.createDirectory(
                        atPath: url.path,
                        withIntermediateDirectories: true
                    )
                    callback(nil, nil)
                } catch {
                    callback(nil, "mkdir: \(error.localizedDescription)")
                }

            case "copyFile":
                guard args.count >= 2,
                      let srcPath = args[0] as? String,
                      let destPath = args[1] as? String else {
                    callback(nil, "copyFile: missing srcPath or destPath")
                    return
                }
                guard let source = self.resolve(srcPath, callback: callback) else { return }
                guard let destination = self.resolve(destPath, callback: callback) else { return }
                do {
                    // Remove destination if it exists (copyItem throws if dest exists)
                    if self.fileManager.fileExists(atPath: destination.path) {
                        try self.fileManager.removeItem(atPath: destination.path)
                    }
                    if let error = self.ensureParentDirectory(of: destination) {
                        callback(nil, "copyFile: \(error)")
                        return
                    }
                    try self.fileManager.copyItem(atPath: source.path, toPath: destination.path)
                    callback(nil, nil)
                } catch {
                    callback(nil, "copyFile: \(error.localizedDescription)")
                }

            case "moveFile":
                guard args.count >= 2,
                      let srcPath = args[0] as? String,
                      let destPath = args[1] as? String else {
                    callback(nil, "moveFile: missing srcPath or destPath")
                    return
                }
                guard let source = self.resolve(srcPath, callback: callback) else { return }
                guard let destination = self.resolve(destPath, callback: callback) else { return }
                do {
                    if self.fileManager.fileExists(atPath: destination.path) {
                        try self.fileManager.removeItem(atPath: destination.path)
                    }
                    if let error = self.ensureParentDirectory(of: destination) {
                        callback(nil, "moveFile: \(error)")
                        return
                    }
                    try self.fileManager.moveItem(atPath: source.path, toPath: destination.path)
                    callback(nil, nil)
                } catch {
                    callback(nil, "moveFile: \(error.localizedDescription)")
                }

            default:
                callback(nil, "FileSystemModule: Unknown method '\(method)'")
            }
        }
    }

    // MARK: - Path helpers

    /// Resolve a JavaScript-supplied path through the sandbox, reporting the
    /// rejection reason to JS when it is not allowed.
    private func resolve(
        _ path: String,
        callback: (Any?, String?) -> Void
    ) -> URL? {
        do {
            return try sandbox.resolve(path, fileManager: fileManager)
        } catch {
            callback(nil, error.localizedDescription)
            return nil
        }
    }

    private func ensureParentDirectory(of url: URL) -> String? {
        let directory = url.deletingLastPathComponent()
        guard !fileManager.fileExists(atPath: directory.path) else { return nil }
        do {
            try fileManager.createDirectory(atPath: directory.path, withIntermediateDirectories: true)
            return nil
        } catch {
            return "could not create directory: \(error.localizedDescription)"
        }
    }

    // MARK: - Download

    /// Stream a remote body to disk.
    ///
    /// The response is written incrementally to a `.part` file rather than
    /// buffered in memory, and the transfer is aborted as soon as it exceeds
    /// ``FileSystemSandbox/maxDownloadBytes``. The request runs on a session
    /// whose delegate forwards TLS challenges to `CertificatePinning.shared`, so
    /// any configured pins apply to downloads too.
    private func downloadFile(
        from url: URL,
        to destination: URL,
        callback: @escaping (Any?, String?) -> Void
    ) {
        guard !isDestroyed else {
            callback(nil, "downloadFile: module has been destroyed")
            return
        }
        if let error = ensureParentDirectory(of: destination) {
            callback(nil, "downloadFile: \(error)")
            return
        }

        let delegate = StreamingDownloadDelegate(
            destination: destination,
            maxBytes: sandbox.maxDownloadBytes,
            fileManager: fileManager
        ) { [weak self] session, failure in
            session.finishTasksAndInvalidate()
            self?.retireDownloadSession(session)
            if let failure {
                callback(nil, failure)
            } else {
                callback(destination.path, nil)
            }
        }

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        registerDownloadSession(session)
        session.dataTask(with: url).resume()
    }

    // MARK: - Lifecycle

    private var isDestroyed: Bool { sessionLock.withLock { destroyed } }

    private func registerDownloadSession(_ session: URLSession) {
        let abandon: Bool = sessionLock.withLock {
            guard !destroyed else { return true }
            downloadSessions.append(session)
            return false
        }
        if abandon {
            session.invalidateAndCancel()
        }
    }

    private func retireDownloadSession(_ session: URLSession) {
        sessionLock.withLock {
            downloadSessions.removeAll { $0 === session }
        }
    }

    public func destroy() {
        let sessions: [URLSession] = sessionLock.withLock {
            guard !destroyed else { return [] }
            destroyed = true
            let active = downloadSessions
            downloadSessions.removeAll()
            return active
        }
        for session in sessions {
            session.invalidateAndCancel()
        }
    }
}

/// Streams a download body to a `.part` file, enforcing a byte cap and routing
/// TLS challenges through the shared certificate pinner.
///
/// `URLSession` retains its delegate until the session is invalidated, and the
/// completion closure is invoked exactly once from `didCompleteWithError`.
///
/// `@unchecked Sendable`: the delegate is called on the session's own queue
/// while the owning module may be torn down on another, so every mutable field
/// is read and written under `stateLock`.
private final class StreamingDownloadDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {

    private let destination: URL
    private let maxBytes: Int
    private let fileManager: FileManager
    private let completion: (URLSession, String?) -> Void

    private let stateLock = NSLock()
    private var handle: FileHandle?
    private var partialURL: URL?
    private var written = 0
    private var failure: String?
    private var completed = false

    init(
        destination: URL,
        maxBytes: Int,
        fileManager: FileManager,
        completion: @escaping (URLSession, String?) -> Void
    ) {
        self.destination = destination
        self.maxBytes = maxBytes
        self.fileManager = fileManager
        self.completion = completion
        super.init()
    }

    private var partial: URL {
        destination.appendingPathExtension("part")
    }

    private func recordFailure(_ message: String) {
        stateLock.withLock {
            if failure == nil { failure = message }
        }
    }

    // MARK: URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            recordFailure("downloadFile: server returned HTTP \(http.statusCode)")
            completionHandler(.cancel)
            return
        }
        if response.expectedContentLength > Int64(maxBytes) {
            recordFailure("downloadFile: response exceeds the \(maxBytes) byte limit")
            completionHandler(.cancel)
            return
        }
        let url = partial
        stateLock.withLock { partialURL = url }
        fileManager.createFile(atPath: url.path, contents: nil)
        do {
            let opened = try FileHandle(forWritingTo: url)
            stateLock.withLock { handle = opened }
            completionHandler(.allow)
        } catch {
            recordFailure("downloadFile: could not open destination for writing: \(error.localizedDescription)")
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let overflow: Bool = stateLock.withLock {
            written += data.count
            return written > maxBytes
        }
        if overflow {
            recordFailure("downloadFile: response exceeds the \(maxBytes) byte limit")
            dataTask.cancel()
            return
        }
        guard let fileHandle = stateLock.withLock({ handle }) else { return }
        do {
            try fileHandle.write(contentsOf: data)
        } catch {
            recordFailure("downloadFile: write failed: \(error.localizedDescription)")
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let (fileHandle, partialPath, failureMessage, firstDelivery): (FileHandle?, URL?, String?, Bool) =
            stateLock.withLock {
                guard !completed else { return (nil, nil, nil, false) }
                completed = true
                let current = handle
                handle = nil
                let message = failure ?? error.map { "downloadFile: \($0.localizedDescription)" }
                return (current, partialURL, message, true)
            }
        guard firstDelivery else { return }

        try? fileHandle?.close()
        defer {
            // Clean up the staging file on every failure path. On success
            // `moveItem` has already consumed it, so the existence check no-ops.
            if let partialPath, fileManager.fileExists(atPath: partialPath.path) {
                try? fileManager.removeItem(at: partialPath)
            }
        }

        if let failureMessage {
            completion(session, failureMessage)
            return
        }
        guard let partialPath else {
            completion(session, "downloadFile: no data received")
            return
        }
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: partialPath, to: destination)
            completion(session, nil)
        } catch {
            completion(session, "downloadFile: could not save file: \(error.localizedDescription)")
        }
    }

    // MARK: URLSessionDelegate (TLS)

    /// Forward trust challenges to the shared pinner so `downloadFile` honours
    /// any certificate pins the host configured. Without this the download would
    /// run on a session with no pinning delegate at all.
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        CertificatePinning.shared.urlSession(session, didReceive: challenge, completionHandler: completionHandler)
    }
}
