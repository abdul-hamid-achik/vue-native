import XCTest
@testable import VueNativeShared

/// Wiring tests proving ``FileSystemModule`` actually routes every path argument
/// through ``FileSystemSandbox``. The sandbox rules themselves are covered by
/// `FileSystemSandboxTests`; these assert the module does not bypass them.
final class FileSystemModuleTests: XCTestCase {

    private let fileManager = FileManager.default
    private var module: FileSystemModule!
    private var scratch: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        scratch = fileManager.temporaryDirectory
            .appendingPathComponent("VueNativeShared-FSTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
        module = FileSystemModule(sandbox: FileSystemSandbox())
    }

    override func tearDownWithError() throws {
        module.destroy()
        try? fileManager.removeItem(at: scratch)
        module = nil
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
        let root = fileManager.temporaryDirectory.resolvingSymlinksInPath().path
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
        let sandbox = FileSystemSandbox()
        for method in ["getDocumentsPath", "getCachesPath"] {
            let path = invoke(method, args: []).result as? String
            let unwrapped = try? XCTUnwrap(path)
            XCTAssertNotNil(unwrapped)
            if let path {
                XCTAssertTrue(
                    sandbox.isAllowed(path),
                    "\(method) returned a path outside the sandbox: \(path)"
                )
            }
        }
    }

    // MARK: - Helper

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
