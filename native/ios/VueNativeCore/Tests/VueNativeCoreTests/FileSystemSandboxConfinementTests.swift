#if canImport(UIKit)
import Foundation
import VueNativeShared
import XCTest
@testable import VueNativeCore

/// Proves the sandbox confinement is actually wired up on the **iOS** target.
///
/// The rules themselves are covered exhaustively by
/// `VueNativeShared/Tests/.../FileSystemSandboxTests.swift` and
/// `FileSystemModuleTests.swift`, which run under `swift test` on the macOS host
/// and therefore never execute against the iOS build. These tests exercise the
/// iOS `FileSystemModule` facade so a wiring regression on this target cannot
/// slip through.
final class FileSystemSandboxConfinementTests: XCTestCase {

    private let fileManager = FileManager.default
    /// Qualified because this test imports both `VueNativeShared` (for
    /// `FileSystemSandbox`) and `@testable VueNativeCore`, and both modules
    /// declare a `FileSystemModule` / `DatabaseModule`.
    private var module: VueNativeCore.FileSystemModule!
    private var scratch: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        scratch = fileManager.temporaryDirectory
            .appendingPathComponent("VueNativeCore-FSConfinement-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
        module = VueNativeCore.FileSystemModule(sandbox: FileSystemSandbox())
    }

    override func tearDownWithError() throws {
        module.destroy()
        try? fileManager.removeItem(at: scratch)
        module = nil
        scratch = nil
        try super.tearDownWithError()
    }

    func testIOSFileSystemModuleRejectsTraversalOnEveryPathMethod() {
        for method in ["readFile", "writeFile", "deleteFile", "exists", "listDirectory", "stat", "mkdir"] {
            let args: [Any] = method == "writeFile" ? ["../../etc/passwd", "owned"] : ["../../etc/passwd"]
            let response = invoke(method, args: args)
            XCTAssertNil(response.result, "iOS \(method) should reject a traversal path")
            XCTAssertEqual(
                response.error,
                "FileSystem: path escapes the app sandbox: '../../etc/passwd'",
                "iOS \(method) produced an unexpected rejection"
            )
        }
    }

    func testIOSFileSystemModuleRejectsReservedOTADirectory() {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let reserved = support?.appendingPathComponent("VueNativeOTA/bundle-deadbeef.js").path
        let path = try? XCTUnwrap(reserved)
        let response = invoke("writeFile", args: [path as Any, "globalThis.__pwned = true;"])
        XCTAssertNil(response.result)
        XCTAssertTrue(
            response.error?.contains("reserved Vue Native directory") == true,
            "iOS writeFile must refuse the OTA bundle store, got: \(String(describing: response.error))"
        )
    }

    func testIOSFileSystemModuleStillRoundTripsInsideTheSandbox() {
        let path = scratch.appendingPathComponent("notes/child.txt").path
        XCTAssertNil(invoke("writeFile", args: [path, "hello"]).error)
        XCTAssertEqual(invoke("exists", args: [path]).result as? Bool, true)
        XCTAssertEqual(invoke("readFile", args: [path]).result as? String, "hello")
        XCTAssertNil(invoke("deleteFile", args: [path]).error)
        XCTAssertEqual(invoke("exists", args: [path]).result as? Bool, false)
    }

    func testIOSDatabaseModuleRejectsPathTraversingNames() {
        let databaseDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("VueNativeCore-DBConfinement-\(UUID().uuidString)", isDirectory: true)
        let database = VueNativeCore.DatabaseModule(databaseDirectory: databaseDirectory)
        defer {
            database.destroy()
            try? fileManager.removeItem(at: databaseDirectory)
        }

        let response = invokeOn(database, "open", args: ["../../evil"])
        XCTAssertNil(response.result)
        XCTAssertEqual(response.error, DatabaseNameValidator.invalidNameError("../../evil"))
        XCTAssertEqual(database.openDatabaseCount, 0)

        // A valid name still opens.
        XCTAssertNil(invokeOn(database, "open", args: ["default"]).error)
        XCTAssertEqual(database.openDatabaseCount, 1)
    }

    // MARK: - Helpers

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

    private func invokeOn(
        _ target: VueNativeCore.DatabaseModule,
        _ method: String,
        args: [Any]
    ) -> (result: Any?, error: String?) {
        var response: (result: Any?, error: String?) = (nil, nil)
        target.invoke(method: method, args: args) { result, error in
            response = (result, error)
        }
        return response
    }
}
#endif
