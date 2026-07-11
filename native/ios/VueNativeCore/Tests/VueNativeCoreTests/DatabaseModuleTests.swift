#if canImport(UIKit)
import XCTest
@testable import VueNativeCore

final class DatabaseModuleTests: XCTestCase {
    private let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("VueNativeCore-DatabaseTests-\(UUID().uuidString)", isDirectory: true)

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
#endif
