import XCTest
@testable import VueNativeShared

/// Wiring tests proving ``FileSystemModule`` actually routes every path argument
/// through ``FileSystemSandbox``. The sandbox rules themselves are covered by
/// `FileSystemSandboxTests`; these assert the module does not bypass them.
final class FileSystemModuleTests: XCTestCase {

    private let fileManager = FileManager.default
    private var sandbox: FileSystemSandbox!
    private var module: FileSystemModule!
    private var scratch: URL!
    private var plantedSentinels: [URL] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        sandbox = FileSystemSandbox()
        // Scratch lives under the sandbox temporary root so every write is in-sandbox.
        scratch = sandbox.temporaryRoot()
            .appendingPathComponent("VueNativeShared-FSTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
        module = FileSystemModule(sandbox: sandbox)
    }

    override func tearDownWithError() throws {
        module.destroy()
        try? fileManager.removeItem(at: scratch)
        for sentinel in plantedSentinels {
            try? fileManager.removeItem(at: sentinel)
        }
        plantedSentinels.removeAll()
        module = nil
        sandbox = nil
        scratch = nil
        try super.tearDownWithError()
    }

    // MARK: - Rejections

    func testEveryReadPathRejectsTraversalOutsideTheSandbox() {
        for method in ["readFile", "deleteFile", "listDirectory", "stat", "exists"] {
            let response = invoke(method, args: ["../../etc/passwd"])
            XCTAssertNil(response.result, "\(method) should reject a traversal path")
            XCTAssertEqual(
                response.error,
                "FileSystem: path escapes the app sandbox: '../../etc/passwd'",
                "\(method) produced an unexpected rejection"
            )
        }
    }

    func testWriteAndMkdirRejectTraversalOutsideTheSandbox() {
        let write = invoke("writeFile", args: ["../../etc/passwd", "owned"])
        XCTAssertNil(write.result)
        XCTAssertTrue(
            write.error?.contains("escapes the app sandbox") == true,
            "writeFile error was \(String(describing: write.error))"
        )

        let mkdir = invoke("mkdir", args: ["/tmp/vuenative-escape-\(UUID().uuidString)"])
        XCTAssertNil(mkdir.result)
        XCTAssertTrue(mkdir.error?.contains("escapes the app sandbox") == true)
    }

    func testCopyAndMoveRejectEscapingSourceAndDestination() {
        let inside = scratch.appendingPathComponent("payload.txt").path
        XCTAssertNil(invoke("writeFile", args: [inside, "data"]).error)

        let escapingDest = invoke("copyFile", args: [inside, "/etc/vuenative-copy"])
        XCTAssertNil(escapingDest.result)
        XCTAssertTrue(escapingDest.error?.contains("escapes the app sandbox") == true)

        let escapingSource = invoke("moveFile", args: ["/etc/passwd", inside])
        XCTAssertNil(escapingSource.result)
        XCTAssertTrue(escapingSource.error?.contains("escapes the app sandbox") == true)

        XCTAssertFalse(fileManager.fileExists(atPath: "/etc/vuenative-copy"))
    }

    func testDeleteFileRefusesSandboxRoot() {
        let root = sandbox.temporaryRoot().path
        let response = invoke("deleteFile", args: [root])
        XCTAssertNil(response.result)
        XCTAssertEqual(response.error, "FileSystem: refusing to delete a sandbox root directory")
        XCTAssertTrue(fileManager.fileExists(atPath: root))
    }

    func testDownloadFileRejectsInsecureAndUnparseableURLs() {
        let destination = scratch.appendingPathComponent("download.bin").path

        let http = invoke("downloadFile", args: ["http://example.com/a.bin", destination])
        XCTAssertNil(http.result)
        XCTAssertEqual(http.error, "downloadFile: refusing non-HTTPS URL: http://example.com/a.bin")

        let file = invoke("downloadFile", args: ["file:///etc/passwd", destination])
        XCTAssertNil(file.result)
        XCTAssertTrue(file.error?.contains("refusing non-HTTPS URL") == true)

        let escaping = invoke("downloadFile", args: ["https://example.com/a.bin", "/etc/a.bin"])
        XCTAssertNil(escaping.result)
        XCTAssertTrue(escaping.error?.contains("escapes the app sandbox") == true)

        XCTAssertFalse(fileManager.fileExists(atPath: destination))
    }

    // MARK: - Redirects

    func testRedirectToInsecureURLFailsTheDownload() throws {
        let destination = scratch.appendingPathComponent("redirected.bin")
        var failures: [String?] = []
        let delegate = StreamingDownloadDelegate(
            destination: destination,
            maxBytes: 1024,
            fileManager: fileManager,
            sandbox: sandbox
        ) { _, failure in
            failures.append(failure)
        }
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let start = try XCTUnwrap(URL(string: "https://example.com/start.bin"))
        let task = session.dataTask(with: start)
        let redirect = try XCTUnwrap(HTTPURLResponse(
            url: start,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "http://example.com/evil.bin"]
        ))
        let insecure = URLRequest(url: try XCTUnwrap(URL(string: "http://example.com/evil.bin")))

        var handled = false
        var followed: URLRequest?
        delegate.urlSession(session, task: task, willPerformHTTPRedirection: redirect, newRequest: insecure) { request in
            handled = true
            followed = request
        }
        XCTAssertTrue(handled, "the redirect decision must be delivered")
        XCTAssertNil(followed, "an insecure redirect must not be followed")

        delegate.urlSession(session, task: task, didCompleteWithError: nil)
        XCTAssertEqual(failures.count, 1, "the completion must fire exactly once")
        XCTAssertEqual(failures.first ?? nil, "downloadFile: redirect to an insecure URL was refused")
        XCTAssertFalse(fileManager.fileExists(atPath: destination.path))
    }

    func testRedirectToSecureURLIsFollowed() throws {
        let destination = scratch.appendingPathComponent("redirected.bin")
        let delegate = StreamingDownloadDelegate(
            destination: destination,
            maxBytes: 1024,
            fileManager: fileManager,
            sandbox: sandbox
        ) { _, _ in }
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let start = try XCTUnwrap(URL(string: "https://example.com/start.bin"))
        let task = session.dataTask(with: start)
        let redirect = try XCTUnwrap(HTTPURLResponse(
            url: start,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://cdn.example.com/file.bin"]
        ))
        let secureTarget = try XCTUnwrap(URL(string: "https://cdn.example.com/file.bin"))

        var followed: URLRequest?
        delegate.urlSession(session, task: task, willPerformHTTPRedirection: redirect, newRequest: URLRequest(url: secureTarget)) { request in
            followed = request
        }
        XCTAssertEqual(followed?.url, secureTarget, "an HTTPS redirect must be followed unchanged")
    }

    // MARK: - Roots and the reserved OTA store are never replaced or moved

    func testCopyRefusesToReplaceASandboxRoot() {
        let payload = scratch.appendingPathComponent("payload.txt").path
        XCTAssertNil(invoke("writeFile", args: [payload, "data"]).error)
        let root = sandbox.temporaryRoot().path

        let response = invoke("copyFile", args: [payload, root])
        XCTAssertNil(response.result)
        XCTAssertEqual(response.error, "copyFile: refusing to touch a sandbox root directory")
        XCTAssertTrue(fileManager.fileExists(atPath: payload), "replacing a root would delete the whole tree")
    }

    func testCopyRefusesToReplaceAnAncestorOfTheOTAStore() throws {
        let sentinel = try plantOTASentinel()
        let support = try XCTUnwrap(sandbox.applicationSupportRoot()).path
        let payload = scratch.appendingPathComponent("payload.txt").path
        XCTAssertNil(invoke("writeFile", args: [payload, "data"]).error)

        let response = invoke("copyFile", args: [payload, support])
        XCTAssertNil(response.result)
        XCTAssertEqual(
            response.error,
            "copyFile: refusing to touch an ancestor of the reserved OTA directory"
        )
        XCTAssertTrue(fileManager.fileExists(atPath: sentinel.path), "the OTA store must survive")
    }

    func testCopyRefusesToCopyAnAncestorOfTheOTAStore() throws {
        let sentinel = try plantOTASentinel()
        let support = try XCTUnwrap(sandbox.applicationSupportRoot()).path
        let copy = scratch.appendingPathComponent("support-copy").path

        let response = invoke("copyFile", args: [support, copy])
        XCTAssertNil(response.result)
        XCTAssertEqual(
            response.error,
            "copyFile: refusing to copy an ancestor of the reserved OTA directory"
        )
        XCTAssertFalse(fileManager.fileExists(atPath: copy), "the OTA store must not be copied out")
        XCTAssertTrue(fileManager.fileExists(atPath: sentinel.path))
    }

    func testMoveRefusesToMoveASandboxRoot() {
        let payload = scratch.appendingPathComponent("payload.txt").path
        XCTAssertNil(invoke("writeFile", args: [payload, "data"]).error)
        let root = sandbox.temporaryRoot().path
        let destination = scratch.appendingPathComponent("moved-root").path

        let response = invoke("moveFile", args: [root, destination])
        XCTAssertNil(response.result)
        XCTAssertEqual(response.error, "moveFile: refusing to touch a sandbox root directory")
        XCTAssertTrue(fileManager.fileExists(atPath: payload), "the root must stay in place")
        XCTAssertFalse(fileManager.fileExists(atPath: destination))
    }

    func testMoveRefusesToReplaceASandboxRoot() {
        let payload = scratch.appendingPathComponent("payload.txt").path
        XCTAssertNil(invoke("writeFile", args: [payload, "data"]).error)
        let root = sandbox.temporaryRoot().path

        let response = invoke("moveFile", args: [payload, root])
        XCTAssertNil(response.result)
        XCTAssertEqual(response.error, "moveFile: refusing to touch a sandbox root directory")
        XCTAssertTrue(fileManager.fileExists(atPath: payload), "the source must not be consumed")
    }

    func testMoveRefusesToMoveAnAncestorOfTheOTAStore() throws {
        let sentinel = try plantOTASentinel()
        let support = try XCTUnwrap(sandbox.applicationSupportRoot()).path
        let destination = scratch.appendingPathComponent("moved-support").path

        let response = invoke("moveFile", args: [support, destination])
        XCTAssertNil(response.result)
        XCTAssertEqual(
            response.error,
            "moveFile: refusing to touch an ancestor of the reserved OTA directory"
        )
        XCTAssertFalse(fileManager.fileExists(atPath: destination))
        XCTAssertTrue(fileManager.fileExists(atPath: sentinel.path), "the OTA store must not move")
    }

    func testMoveRefusesToReplaceAnAncestorOfTheOTAStore() throws {
        let sentinel = try plantOTASentinel()
        let support = try XCTUnwrap(sandbox.applicationSupportRoot()).path
        let payload = scratch.appendingPathComponent("payload.txt").path
        XCTAssertNil(invoke("writeFile", args: [payload, "data"]).error)

        let response = invoke("moveFile", args: [payload, support])
        XCTAssertNil(response.result)
        XCTAssertEqual(
            response.error,
            "moveFile: refusing to touch an ancestor of the reserved OTA directory"
        )
        XCTAssertTrue(fileManager.fileExists(atPath: payload), "the source must not be consumed")
        XCTAssertTrue(fileManager.fileExists(atPath: sentinel.path), "the OTA store must survive")
    }

    func testDownloadRefusesToReplaceASandboxRoot() {
        let root = sandbox.temporaryRoot().path
        let payload = scratch.appendingPathComponent("payload.txt").path
        XCTAssertNil(invoke("writeFile", args: [payload, "data"]).error)

        // Loopback HTTPS: a missing guard fails fast with a connection error instead of
        // reaching the network.
        let response = invoke("downloadFile", args: ["https://127.0.0.1:1/payload.bin", root])
        XCTAssertNil(response.result)
        XCTAssertEqual(response.error, "downloadFile: refusing to touch a sandbox root directory")
        XCTAssertTrue(fileManager.fileExists(atPath: payload), "the download must not replace the root")
    }

    func testDownloadRefusesToReplaceAnAncestorOfTheOTAStore() throws {
        let sentinel = try plantOTASentinel()
        let support = try XCTUnwrap(sandbox.applicationSupportRoot()).path

        let response = invoke("downloadFile", args: ["https://127.0.0.1:1/bundle.js", support])
        XCTAssertNil(response.result)
        XCTAssertEqual(
            response.error,
            "downloadFile: refusing to touch an ancestor of the reserved OTA directory"
        )
        XCTAssertTrue(fileManager.fileExists(atPath: sentinel.path), "the OTA store must survive")
    }

    // MARK: - Legitimate in-sandbox use still works

    func testReadWriteRoundTripsInsideTheSandbox() {
        let path = scratch.appendingPathComponent("notes/child.txt").path

        XCTAssertNil(invoke("writeFile", args: [path, "hello"]).error)
        XCTAssertEqual(invoke("exists", args: [path]).result as? Bool, true)
        XCTAssertEqual(invoke("readFile", args: [path]).result as? String, "hello")

        let stat = invoke("stat", args: [path]).result as? [String: Any]
        XCTAssertEqual(stat?["size"] as? Int, 5)
        XCTAssertEqual(stat?["isDirectory"] as? Bool, false)

        let copied = scratch.appendingPathComponent("copy.txt").path
        XCTAssertNil(invoke("copyFile", args: [path, copied]).error)
        XCTAssertEqual(invoke("readFile", args: [copied]).result as? String, "hello")

        let moved = scratch.appendingPathComponent("moved.txt").path
        XCTAssertNil(invoke("moveFile", args: [copied, moved]).error)
        XCTAssertEqual(invoke("exists", args: [copied]).result as? Bool, false)
        XCTAssertEqual(invoke("readFile", args: [moved]).result as? String, "hello")

        XCTAssertNil(invoke("deleteFile", args: [moved]).error)
        XCTAssertEqual(invoke("exists", args: [moved]).result as? Bool, false)
    }

    func testBase64RoundTripAndDirectoryListing() {
        let directory = scratch.appendingPathComponent("listing", isDirectory: true).path
        XCTAssertNil(invoke("mkdir", args: [directory]).error)

        let path = "\(directory)/binary.bin"
        let encoded = Data([0x00, 0xFF, 0x10]).base64EncodedString()
        XCTAssertNil(invoke("writeFile", args: [path, encoded, "base64"]).error)
        XCTAssertEqual(invoke("readFile", args: [path, "base64"]).result as? String, encoded)

        let listing = invoke("listDirectory", args: [directory]).result as? [String]
        XCTAssertEqual(listing, ["binary.bin"])
    }

    func testDocumentAndCachePathsAreInsideTheSandbox() {
        let expected = [
            "getDocumentsPath": sandbox.documentsRoot()?.path,
            "getCachesPath": sandbox.cachesRoot()?.path,
        ]
        for (method, scopedPath) in expected {
            let path = invoke(method, args: []).result as? String
            XCTAssertNotNil(path, "\(method) returned no path")
            if let path {
                XCTAssertTrue(
                    sandbox.isAllowed(path),
                    "\(method) returned a path outside the sandbox: \(path)"
                )
                // JS must receive the same scoped directory that relative paths use.
                XCTAssertEqual(path, scopedPath, "\(method) must report the sandbox root")
            }
        }
    }

    // MARK: - Helper

    /// Plants a file inside the reserved OTA directory so tests can prove it survives.
    /// The file is removed in `tearDownWithError`; the directory itself is left alone,
    /// because on a real machine it may hold genuine OTA bundles.
    private func plantOTASentinel() throws -> URL {
        let reserved = try XCTUnwrap(sandbox.reservedOTADirectory())
        try fileManager.createDirectory(at: reserved, withIntermediateDirectories: true)
        let sentinel = reserved.appendingPathComponent("sentinel-\(UUID().uuidString).js")
        XCTAssertTrue(fileManager.createFile(atPath: sentinel.path, contents: Data("bundle".utf8)))
        plantedSentinels.append(sentinel)
        return sentinel
    }

    private func invoke(
        _ method: String,
        args: [Any],
        timeout: TimeInterval = 5
    ) -> (result: Any?, error: String?) {
        let completed = expectation(description: "\(method) callback")
        var response: (result: Any?, error: String?) = (nil, nil)
        module.invoke(method: method, args: args) { result, error in
            response = (result, error)
            completed.fulfill()
        }
        wait(for: [completed], timeout: timeout)
        return response
    }
}
