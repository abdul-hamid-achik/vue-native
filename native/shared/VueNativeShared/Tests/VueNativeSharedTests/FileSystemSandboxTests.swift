import XCTest
@testable import VueNativeShared

/// Confinement tests for ``FileSystemSandbox``.
///
/// These are the regression tests for P0-2: without confinement, arbitrary
/// JavaScript could read, write and delete anywhere the app UID reached.
final class FileSystemSandboxTests: XCTestCase {

    private let fileManager = FileManager.default
    private var sandbox: FileSystemSandbox!
    private var scratch: URL!
    private var createdSymlinks: [URL] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        sandbox = FileSystemSandbox()
        scratch = fileManager.temporaryDirectory
            .appendingPathComponent("VueNativeShared-SandboxTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        for symlink in createdSymlinks {
            try? fileManager.removeItem(at: symlink)
        }
        createdSymlinks.removeAll()
        try? fileManager.removeItem(at: scratch)
        sandbox = nil
        scratch = nil
        try super.tearDownWithError()
    }

    // MARK: - Rejections

    func testRejectsAbsoluteTraversalToEtcPasswd() {
        XCTAssertThrowsError(try sandbox.resolve("../../etc/passwd")) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "FileSystem: path escapes the app sandbox: '../../etc/passwd'"
            )
        }
    }

    func testRejectsAbsolutePathOutsideEveryRoot() {
        XCTAssertThrowsError(try sandbox.resolve("/etc/passwd")) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "FileSystem: path escapes the app sandbox: '/etc/passwd'"
            )
        }
        XCTAssertThrowsError(try sandbox.resolve("/etc"))
    }

    func testRejectsEmptyAndWhitespaceOnlyPath() {
        XCTAssertThrowsError(try sandbox.resolve("")) { error in
            XCTAssertEqual(error.localizedDescription, "FileSystem: path is empty")
        }
        XCTAssertThrowsError(try sandbox.resolve("   \n "))
    }

    func testRejectsSymlinkThatEscapesTheSandbox() throws {
        // `/tmp` is not one of the sandbox roots on macOS (the temporary root is
        // `/var/folders/...`), so a symlink to it must not become a way in.
        let outsideTarget = URL(fileURLWithPath: "/tmp")
        XCTAssertFalse(
            sandbox.allowedRoots().contains { outsideTarget.resolvingSymlinksInPath().path.hasPrefix($0.path) },
            "test precondition: /tmp must be outside every sandbox root"
        )

        let link = scratch.appendingPathComponent("escape-link")
        try fileManager.createSymbolicLink(at: link, withDestinationURL: outsideTarget)
        createdSymlinks.append(link)

        XCTAssertThrowsError(try sandbox.resolve(link.appendingPathComponent("passwd").path)) { error in
            XCTAssertTrue(
                error.localizedDescription.contains("escapes the app sandbox"),
                "symlink escape was not rejected: \(error.localizedDescription)"
            )
        }
        XCTAssertFalse(sandbox.isAllowed(link.appendingPathComponent("passwd").path))
    }

    func testRejectsReservedOTABundleDirectory() throws {
        guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw XCTSkip("no application support directory on this platform")
        }
        let reserved = support.appendingPathComponent("VueNativeOTA/bundle-deadbeef.js")
        XCTAssertThrowsError(try sandbox.resolve(reserved.path)) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "FileSystem: '\(reserved.path)' is a reserved Vue Native directory"
            )
        }
        // The directory itself is reserved too, not just its contents.
        XCTAssertThrowsError(try sandbox.resolve(support.appendingPathComponent("VueNativeOTA").path))
    }

    // MARK: - Accepted paths

    func testAcceptsPathsInsideEverySandboxRoot() throws {
        for root in sandbox.allowedRoots() {
            let candidate = root.appendingPathComponent("vuenative-sandbox-test-\(UUID().uuidString).txt")
            let resolved = try sandbox.resolve(candidate.path)
            XCTAssertTrue(
                resolved.path.hasPrefix(root.path),
                "\(resolved.path) should stay inside \(root.path)"
            )
            XCTAssertTrue(sandbox.isAllowed(candidate.path))
        }
    }

    func testResolvesNonExistentPathAgainstExistingAncestor() throws {
        // `writeFile` and `mkdir` targets do not exist yet; resolution must still
        // confine them rather than passing the raw string through.
        let target = scratch
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("leaf.txt")
        let resolved = try sandbox.resolve(target.path)
        XCTAssertEqual(resolved.path, target.resolvingSymlinksInPath().path)
    }

    func testRelativePathIsAnchoredAtDocuments() throws {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw XCTSkip("no documents directory on this platform")
        }
        let resolved = try sandbox.resolve("vuenative-relative.txt")
        XCTAssertEqual(
            resolved.path,
            documents.resolvingSymlinksInPath().appendingPathComponent("vuenative-relative.txt").path
        )
    }

    func testSandboxRootsAreRecognisedAndNotDeletableContent() throws {
        let root = fileManager.temporaryDirectory.resolvingSymlinksInPath()
        XCTAssertTrue(sandbox.isSandboxRoot(root))
        XCTAssertFalse(sandbox.isSandboxRoot(root.appendingPathComponent("child.txt")))
        // A working directory INSIDE a root is not a root: deleting it is fine.
        XCTAssertFalse(sandbox.isSandboxRoot(try sandbox.resolve(scratch.path)))
    }

    // MARK: - Downloads

    func testDownloadRequiresHTTPSByDefault() throws {
        XCTAssertFalse(sandbox.allowInsecureDownloads)
        XCTAssertTrue(sandbox.isSecureDownload(try XCTUnwrap(URL(string: "https://example.com/a.bin"))))
        XCTAssertFalse(sandbox.isSecureDownload(try XCTUnwrap(URL(string: "http://example.com/a.bin"))))
        XCTAssertFalse(sandbox.isSecureDownload(try XCTUnwrap(URL(string: "file:///etc/passwd"))))
        XCTAssertFalse(sandbox.isSecureDownload(try XCTUnwrap(URL(string: "ftp://example.com/a.bin"))))
    }

    func testLoopbackDownloadsStayAllowedForLocalDevelopment() throws {
        XCTAssertTrue(sandbox.isSecureDownload(try XCTUnwrap(URL(string: "http://localhost:8080/a.bin"))))
        XCTAssertTrue(sandbox.isSecureDownload(try XCTUnwrap(URL(string: "http://127.0.0.1/a.bin"))))
    }

    func testHostCanOptIntoInsecureDownloads() throws {
        sandbox.allowInsecureDownloads = true
        XCTAssertTrue(sandbox.isSecureDownload(try XCTUnwrap(URL(string: "http://example.com/a.bin"))))
    }

    func testDefaultDownloadCapIs25MiB() {
        XCTAssertEqual(FileSystemSandbox.defaultMaxDownloadBytes, 25 * 1024 * 1024)
        XCTAssertEqual(sandbox.maxDownloadBytes, 25 * 1024 * 1024)
        sandbox.maxDownloadBytes = 1024
        XCTAssertEqual(sandbox.maxDownloadBytes, 1024)
    }
}
