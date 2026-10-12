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
        // Scratch lives under the sandbox temporary root: on unsandboxed macOS the
        // bare TMPDIR is shared with other apps and is not a root.
        scratch = sandbox.temporaryRoot()
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
        let support = try XCTUnwrap(sandbox.applicationSupportRoot(), "no application support root")
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
        let documents = try XCTUnwrap(sandbox.documentsRoot(), "no documents root")
        let resolved = try sandbox.resolve("vuenative-relative.txt")
        XCTAssertEqual(
            resolved.path,
            documents.appendingPathComponent("vuenative-relative.txt").path
        )
        XCTAssertTrue(resolved.path.hasPrefix(documents.path + "/"))
    }

    func testSandboxRootsAreRecognisedAndNotDeletableContent() throws {
        let root = sandbox.temporaryRoot()
        XCTAssertTrue(sandbox.isSandboxRoot(root))
        XCTAssertFalse(sandbox.isSandboxRoot(root.appendingPathComponent("child.txt")))
        // A working directory INSIDE a root is not a root: deleting it is fine.
        XCTAssertFalse(sandbox.isSandboxRoot(try sandbox.resolve(scratch.path)))
    }

    func testIsAncestorOfReservedOnlyMatchesStrictAncestors() throws {
        let support = try XCTUnwrap(sandbox.applicationSupportRoot())
        let reserved = try XCTUnwrap(sandbox.reservedOTADirectory())

        XCTAssertTrue(sandbox.isAncestorOfReserved(support), "the App Support root contains the OTA store")
        XCTAssertFalse(sandbox.isAncestorOfReserved(try XCTUnwrap(sandbox.cachesRoot())))
        XCTAssertFalse(sandbox.isAncestorOfReserved(reserved), "the OTA directory is not its own ancestor")
        XCTAssertFalse(sandbox.isAncestorOfReserved(reserved.appendingPathComponent("bundle-deadbeef.js")))
        // A sibling that merely shares the name prefix is not an ancestor.
        XCTAssertFalse(sandbox.isAncestorOfReserved(support.appendingPathComponent("VueNativeOTA-extra")))
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

    // MARK: - Scoped roots on unsandboxed macOS

    #if os(macOS)
    private func canonicalPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    func testUnsandboxedRootsAreScopedToThisApp() throws {
        try XCTSkipIf(FileSystemSandbox.isAppSandboxed, "sandboxed builds keep the system directories")

        let documents = canonicalPath(fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents"))
        let support = canonicalPath(
            try XCTUnwrap(fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
        )
        let caches = canonicalPath(
            try XCTUnwrap(fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first)
        )
        let temporary = canonicalPath(fileManager.temporaryDirectory)
        let shared: Set<String> = [documents, support, caches, temporary]

        let roots = sandbox.allowedRoots().map(\.path)
        XCTAssertEqual(roots.count, 4, "documents, caches, application support and temporary roots")
        for root in roots {
            XCTAssertFalse(shared.contains(root), "\(root) is a directory shared with every app")
        }

        // Caches, Application Support and TMPDIR each hold one per-app folder.
        for directory in [caches, support, temporary] {
            XCTAssertTrue(
                roots.contains { URL(fileURLWithPath: $0).deletingLastPathComponent().path == directory },
                "no sandbox root is a per-app folder under \(directory)"
            )
        }

        // The documents root is per-app too, inside Application Support.
        let scopedDocuments = try XCTUnwrap(sandbox.documentsRoot())
        XCTAssertEqual(scopedDocuments.lastPathComponent, "Documents")
        XCTAssertEqual(scopedDocuments.deletingLastPathComponent().deletingLastPathComponent().path, support)
        XCTAssertFalse(sandbox.allowsUserDocumentsDirectory)
    }

    func testSharedUserDirectoriesAreRejectedWhenUnsandboxed() throws {
        try XCTSkipIf(FileSystemSandbox.isAppSandboxed, "sandboxed builds keep the system directories")

        let rejected = [
            "~/Documents/vuenative-escape.txt",
            "~/Library/Application Support/other-app/state.json",
            "~/Library/Caches/other-app/cache.bin",
        ]
        for path in rejected {
            XCTAssertThrowsError(try sandbox.resolve(path), path) { error in
                XCTAssertEqual(
                    error.localizedDescription,
                    "FileSystem: path escapes the app sandbox: '\(path)'"
                )
            }
        }

        let bareTemporary = fileManager.temporaryDirectory.appendingPathComponent("shared-file.txt").path
        XCTAssertThrowsError(try sandbox.resolve(bareTemporary), "the shared TMPDIR must not be a root")
        XCTAssertFalse(sandbox.isSandboxRoot(fileManager.temporaryDirectory))
    }

    func testAllowsUserDocumentsDirectoryMakesRealDocumentsARoot() throws {
        try XCTSkipIf(FileSystemSandbox.isAppSandboxed, "sandboxed builds keep the system directories")

        let realDocuments = try XCTUnwrap(fileManager.urls(for: .documentDirectory, in: .userDomainMask).first)
        sandbox.allowsUserDocumentsDirectory = true

        XCTAssertEqual(sandbox.documentsRoot()?.path, canonicalPath(realDocuments))
        XCTAssertTrue(sandbox.isSandboxRoot(realDocuments))
        XCTAssertNoThrow(try sandbox.resolve("~/Documents/vuenative-opt-in.txt"))
    }
    #endif

    func testRecordingsAreWrittenWhereFileSystemCanReadThemBack() {
        // AudioModule hands the recording path to JS, which may read or upload it
        // through useFileSystem, so it must resolve inside the sandbox. On an
        // unsandboxed macOS host the bare temporary directory no longer does.
        let url = AudioModule.recordingURL(fileExtension: "m4a")
        XCTAssertTrue(FileSystemSandbox.shared.isAllowed(url.path), "\(url.path) must be inside the sandbox")
        XCTAssertEqual(url.pathExtension, "m4a")
    }
}
