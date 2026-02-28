import Foundation
import SQLite3

/// Native module for SQLite database access.
/// Uses the sqlite3 C API (built into both iOS and macOS, no external dependencies).
/// Supports multiple named databases, parameterized queries, and transactions.
public final class DatabaseModule: NativeModule {
    public let moduleName = "Database"

    /// Open database handles keyed by database name.
    private var databases: [String: OpaquePointer] = [:]

    /// Directory for database files.
    private var dbDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("databases", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public init() {}

    public func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "open":
            let name = args.first as? String ?? "default"
            open(name: name, callback: callback)
        case "close":
            let name = args.first as? String ?? "default"
            close(name: name, callback: callback)
        case "execute":
            let name = args.count > 0 ? (args[0] as? String ?? "default") : "default"
            let sql = args.count > 1 ? (args[1] as? String ?? "") : ""
            let params = args.count > 2 ? (args[2] as? [Any] ?? []) : []
            execute(name: name, sql: sql, params: params, callback: callback)
        case "query":
            let name = args.count > 0 ? (args[0] as? String ?? "default") : "default"
            let sql = args.count > 1 ? (args[1] as? String ?? "") : ""
            let params = args.count > 2 ? (args[2] as? [Any] ?? []) : []
            query(name: name, sql: sql, params: params, callback: callback)
        case "executeTransaction":
            let name = args.count > 0 ? (args[0] as? String ?? "default") : "default"
            let statements = args.count > 1 ? (args[1] as? [[String: Any]] ?? []) : []
            executeTransaction(name: name, statements: statements, callback: callback)
        default:
            callback(nil, "DatabaseModule: unknown method '\(method)'")
        }
    }

    // MARK: - Open / Close

    private func open(name: String, callback: @escaping (Any?, String?) -> Void) {
        if databases[name] != nil {
            callback(true, nil)
            return
        }

        let path = dbDirectory.appendingPathComponent("\(name).sqlite").path
        var db: OpaquePointer?

        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(path, &db, flags, nil)
        if result == SQLITE_OK, let db = db {
            // Enable WAL mode for better concurrent read/write performance
            sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
            databases[name] = db
            callback(true, nil)
        } else {
            let errorMsg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
            if db != nil { sqlite3_close(db) }
            callback(nil, "Failed to open database '\(name)': \(errorMsg)")
        }
    }

    private func close(name: String, callback: @escaping (Any?, String?) -> Void) {
        guard let db = databases.removeValue(forKey: name) else {
            callback(nil, nil)
            return
        }
        sqlite3_close(db)
        callback(nil, nil)
    }

    // MARK: - Execute (INSERT, UPDATE, DELETE, CREATE TABLE, etc.)

    private func execute(name: String, sql: String, params: [Any], callback: @escaping (Any?, String?) -> Void) {
        guard let db = getOrOpen(name: name, callback: callback) else { return }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db))
            callback(nil, "SQL prepare error: \(err)")
            return
        }
        defer { sqlite3_finalize(stmt) }

        bindParams(stmt: stmt!, params: params)

        let stepResult = sqlite3_step(stmt)
        if stepResult == SQLITE_DONE || stepResult == SQLITE_ROW {
            let rowsAffected = sqlite3_changes(db)
            let lastInsertId = sqlite3_last_insert_rowid(db)
            var result: [String: Any] = ["rowsAffected": Int(rowsAffected)]
            if lastInsertId > 0 {
                result["insertId"] = Int(lastInsertId)
            }
            callback(result, nil)
        } else {
            let err = String(cString: sqlite3_errmsg(db))
            callback(nil, "SQL execute error: \(err)")
        }
    }

    // MARK: - Query (SELECT)

    private func query(name: String, sql: String, params: [Any], callback: @escaping (Any?, String?) -> Void) {
        guard let db = getOrOpen(name: name, callback: callback) else { return }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db))
            callback(nil, "SQL prepare error: \(err)")
            return
        }
        defer { sqlite3_finalize(stmt) }

        bindParams(stmt: stmt!, params: params)

        var rows: [[String: Any]] = []
        let columnCount = sqlite3_column_count(stmt)

        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<columnCount {
                let colName = String(cString: sqlite3_column_name(stmt, i))
                row[colName] = columnValue(stmt: stmt!, index: i)
            }
            rows.append(row)
        }

        callback(rows, nil)
    }

    // MARK: - Transaction

    private func executeTransaction(name: String, statements: [[String: Any]], callback: @escaping (Any?, String?) -> Void) {
        guard let db = getOrOpen(name: name, callback: callback) else { return }

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

        var results: [[String: Any]] = []

        for stmtData in statements {
            let sql = stmtData["sql"] as? String ?? ""
            let params = stmtData["params"] as? [Any] ?? []

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                let err = String(cString: sqlite3_errmsg(db))
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                callback(nil, "Transaction SQL prepare error: \(err)")
                return
            }

            bindParams(stmt: stmt!, params: params)

            let stepResult = sqlite3_step(stmt)
            sqlite3_finalize(stmt)

            if stepResult == SQLITE_DONE || stepResult == SQLITE_ROW {
                let rowsAffected = sqlite3_changes(db)
                let lastInsertId = sqlite3_last_insert_rowid(db)
                var result: [String: Any] = ["rowsAffected": Int(rowsAffected)]
                if lastInsertId > 0 {
                    result["insertId"] = Int(lastInsertId)
                }
                results.append(result)
            } else {
                let err = String(cString: sqlite3_errmsg(db))
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                callback(nil, "Transaction execute error: \(err)")
                return
            }
        }

        sqlite3_exec(db, "COMMIT", nil, nil, nil)
        callback(results, nil)
    }

    // MARK: - Helpers

    /// Get an existing database handle or auto-open it.
    private func getOrOpen(name: String, callback: @escaping (Any?, String?) -> Void) -> OpaquePointer? {
        if let db = databases[name] { return db }

        // Auto-open
        let path = dbDirectory.appendingPathComponent("\(name).sqlite").path
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(path, &db, flags, nil)
        if result == SQLITE_OK, let db = db {
            sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
            databases[name] = db
            return db
        } else {
            let errorMsg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
            if db != nil { sqlite3_close(db) }
            callback(nil, "Failed to auto-open database '\(name)': \(errorMsg)")
            return nil
        }
    }

    /// Bind parameter array to a prepared statement. Supports String, Int, Double, Bool, nil/NSNull.
    private func bindParams(stmt: OpaquePointer, params: [Any]) {
        for (i, param) in params.enumerated() {
            let idx = Int32(i + 1)
            if param is NSNull {
                sqlite3_bind_null(stmt, idx)
            } else if let s = param as? String {
                sqlite3_bind_text(stmt, idx, (s as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else if let n = param as? Int {
                sqlite3_bind_int64(stmt, idx, Int64(n))
            } else if let d = param as? Double {
                sqlite3_bind_double(stmt, idx, d)
            } else if let b = param as? Bool {
                sqlite3_bind_int(stmt, idx, b ? 1 : 0)
            } else {
                // Fallback: bind as text
                let str = "\(param)"
                sqlite3_bind_text(stmt, idx, (str as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        }
    }

    /// Extract a column value from the current row of a statement.
    private func columnValue(stmt: OpaquePointer, index: Int32) -> Any {
        let type = sqlite3_column_type(stmt, index)
        switch type {
        case SQLITE_INTEGER:
            return Int(sqlite3_column_int64(stmt, index))
        case SQLITE_FLOAT:
            return sqlite3_column_double(stmt, index)
        case SQLITE_TEXT:
            return String(cString: sqlite3_column_text(stmt, index))
        case SQLITE_BLOB:
            // Return blob as base64 string
            if let data = sqlite3_column_blob(stmt, index) {
                let bytes = sqlite3_column_bytes(stmt, index)
                let d = Data(bytes: data, count: Int(bytes))
                return d.base64EncodedString()
            }
            return NSNull()
        case SQLITE_NULL:
            return NSNull()
        default:
            return NSNull()
        }
    }
}
