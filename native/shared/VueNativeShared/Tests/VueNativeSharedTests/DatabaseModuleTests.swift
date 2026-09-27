import XCTest
@testable import VueNativeShared

final class DatabaseModuleTests: XCTestCase {
    private let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("VueNativeShared-DatabaseTests-\(UUID().uuidString)", isDirectory: true)

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: databaseDirectory)
        try super.tearDownWithError()
    }

    func testEmptyAndCommentOnlyStatementsReturnErrors() {
        let module = DatabaseModule(databaseDirectory: databaseDirectory)
        defer { module.destroy() }

        let execute = invoke(
            module,
            method: "execute",
            args: ["edge-cases", "", []]
        )
        XCTAssertNil(execute.result)
        XCTAssertEqual(execute.error, "SQL prepare error: no executable statement")

        let query = invoke(
            module,
            method: "query",
            args: ["edge-cases", "-- comment only\n", []]
        )
        XCTAssertNil(query.result)
        XCTAssertEqual(query.error, "SQL prepare error: no executable statement")

        let transaction = invoke(
            module,
            method: "executeTransaction",
            args: ["edge-cases", [["sql": "/* comment only */", "params": []]]]
        )
        XCTAssertNil(transaction.result)
        XCTAssertEqual(
            transaction.error,
            "Transaction SQL prepare error: no executable statement"
        )
    }

    func testDestroyClosesHandlesAndAllowsReopening() {
        let module = DatabaseModule(databaseDirectory: databaseDirectory)

        let firstOpen = invoke(module, method: "open", args: ["lifecycle"])
        XCTAssertEqual(firstOpen.result as? Bool, true)
        XCTAssertNil(firstOpen.error)
        XCTAssertEqual(module.openDatabaseCount, 1)

        module.destroy()
        XCTAssertEqual(module.openDatabaseCount, 0)

        module.destroy()
        XCTAssertEqual(module.openDatabaseCount, 0)

        let secondOpen = invoke(module, method: "open", args: ["lifecycle"])
        XCTAssertEqual(secondOpen.result as? Bool, true)
        XCTAssertNil(secondOpen.error)
        XCTAssertEqual(module.openDatabaseCount, 1)

        let execute = invoke(
            module,
            method: "execute",
            args: ["lifecycle", "CREATE TABLE IF NOT EXISTS items (id INTEGER)", []]
        )
        XCTAssertNil(execute.error)

        module.destroy()
        XCTAssertEqual(module.openDatabaseCount, 0)
    }

    // MARK: - Database name validation (P1-3)

    func testInvalidDatabaseNamesAreRejectedBeforeTouchingTheFilesystem() {
        let module = DatabaseModule(databaseDirectory: databaseDirectory)
        defer { module.destroy() }

        let rejected = ["../evil", "../../evil", "a/b", "", " ", "with space", "semi;colon", String(repeating: "a", count: 65)]
        for name in rejected {
            for method in ["open", "close", "execute", "query"] {
                let args: [Any] = method == "execute" || method == "query"
                    ? [name, "SELECT 1", []]
                    : [name]
                let response = invoke(module, method: method, args: args)
                XCTAssertNil(response.result, "\(method) accepted invalid name '\(name)'")
                XCTAssertEqual(
                    response.error,
                    DatabaseNameValidator.invalidNameError(name),
                    "\(method) produced an unexpected error for '\(name)'"
                )
            }
        }

        let transaction = invoke(
            module,
            method: "executeTransaction",
            args: ["../evil", [["sql": "SELECT 1", "params": []]]]
        )
        XCTAssertNil(transaction.result)
        XCTAssertEqual(transaction.error, DatabaseNameValidator.invalidNameError("../evil"))

        // Nothing escaped the configured database directory.
        let escaped = databaseDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("evil.sqlite")
        XCTAssertFalse(FileManager.default.fileExists(atPath: escaped.path))
        XCTAssertEqual(module.openDatabaseCount, 0)
    }

    func testValidDatabaseNamesStillWorkEndToEnd() {
        let module = DatabaseModule(databaseDirectory: databaseDirectory)
        defer { module.destroy() }

        for name in ["default", "my-app_1", "A9", String(repeating: "z", count: 64)] {
            XCTAssertNil(invoke(module, method: "open", args: [name]).error, "open rejected '\(name)'")
            let create = invoke(
                module,
                method: "execute",
                args: [name, "CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY, label TEXT)", []]
            )
            XCTAssertNil(create.error, "create table failed for '\(name)': \(String(describing: create.error))")

            let insert = invoke(
                module,
                method: "execute",
                args: [name, "INSERT INTO items (label) VALUES (?)", ["alpha"]]
            )
            XCTAssertNil(insert.error)

            let rows = invoke(module, method: "query", args: [name, "SELECT label FROM items", []])
            XCTAssertEqual((rows.result as? [[String: Any]])?.first?["label"] as? String, "alpha")

            XCTAssertTrue(
                FileManager.default.fileExists(atPath: databaseDirectory.appendingPathComponent("\(name).sqlite").path),
                "'\(name)' should be stored as <name>.sqlite inside the database directory"
            )
        }
    }

    func testAttachDatabaseIsRefusedSoSqlCannotReachAnotherPath() {
        let module = DatabaseModule(databaseDirectory: databaseDirectory)
        defer { module.destroy() }

        XCTAssertNil(invoke(module, method: "open", args: ["guarded"]).error)

        let target = databaseDirectory.appendingPathComponent("attached.sqlite").path
        let attach = invoke(
            module,
            method: "execute",
            args: ["guarded", "ATTACH DATABASE ? AS payload", [target]]
        )
        XCTAssertNotNil(attach.error, "ATTACH DATABASE must be refused when the attached limit is 0")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: target),
            "ATTACH DATABASE created a file outside the named database"
        )
    }

    private func invoke(
        _ module: DatabaseModule,
        method: String,
        args: [Any]
    ) -> (result: Any?, error: String?) {
        var response: (result: Any?, error: String?)?
        module.invoke(method: method, args: args) { result, error in
            response = (result, error)
        }
        XCTAssertNotNil(response, "Database operations should complete synchronously")
        return response ?? (nil, "Callback was not invoked")
    }
}
