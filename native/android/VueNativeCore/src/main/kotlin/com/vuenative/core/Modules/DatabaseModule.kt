package com.vuenative.core

import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import java.io.File

class DatabaseModule : NativeModule {
    override val moduleName = "Database"

    private var context: Context? = null
    private val databases = mutableMapOf<String, SQLiteDatabase>()
    private val lock = Object()

    /**
     * Database names are interpolated into a file path, so they must be
     * restricted to a character set that cannot express a path separator or a
     * traversal segment. Without this, `open("../../evil")` produced
     * `<filesDir>/databases/../../evil.sqlite`, and combined with the arbitrary
     * SQL accepted by `execute`/`query` an `ATTACH DATABASE` could reach any
     * writable path in the app sandbox.
     *
     * The Apple implementation additionally caps `SQLITE_LIMIT_ATTACHED` at 0;
     * the Android framework `SQLiteDatabase` API exposes no equivalent limit, so
     * name validation is the enforced control here.
     */
    private companion object {
        val NAME_PATTERN = Regex("^[A-Za-z0-9_-]{1,64}$")

        /** Kept identical to the Apple implementation so behaviour matches. */
        fun invalidNameError(name: String) =
            "Invalid database name '$name'; expected 1-64 characters of A-Z, a-z, 0-9, underscore, or hyphen"

        fun validationError(name: String): String? =
            if (NAME_PATTERN.matches(name)) null else invalidNameError(name)

        /** Throws so the single `invoke` catch-all surfaces the reason verbatim. */
        fun requireValidName(name: String) {
            validationError(name)?.let { throw IllegalArgumentException(it) }
        }
    }

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        synchronized(lock) {
            try {
                when (method) {
                    "open" -> {
                        val name = args.getOrNull(0)?.toString() ?: "default"
                        open(name, callback)
                    }
                    "close" -> {
                        val name = args.getOrNull(0)?.toString() ?: "default"
                        close(name, callback)
                    }
                    "execute" -> {
                        val name = args.getOrNull(0)?.toString() ?: "default"
                        val sql = args.getOrNull(1)?.toString() ?: ""
                        val params = toParamArray(args.getOrNull(2))
                        execute(name, sql, params, callback)
                    }
                    "query" -> {
                        val name = args.getOrNull(0)?.toString() ?: "default"
                        val sql = args.getOrNull(1)?.toString() ?: ""
                        val params = toStringArray(args.getOrNull(2))
                        query(name, sql, params, callback)
                    }
                    "executeTransaction" -> {
                        val name = args.getOrNull(0)?.toString() ?: "default"
                        val statements = args.getOrNull(1) as? List<*> ?: emptyList<Any>()
                        executeTransaction(name, statements, callback)
                    }
                    else -> callback(null, "DatabaseModule: unknown method '$method'")
                }
            } catch (e: IllegalArgumentException) {
                // Name-validation rejection: report the reason, not a wrapper.
                callback(null, e.message)
            } catch (e: Exception) {
                callback(null, "DatabaseModule error: ${e.message}")
            }
        }
    }

    override fun destroy() {
        synchronized(lock) {
            databases.values.forEach { it.close() }
            databases.clear()
        }
    }

    // -- Open / Close --

    private fun open(name: String, callback: (Any?, String?) -> Unit) {
        requireValidName(name)
        if (databases.containsKey(name)) {
            callback(true, null)
            return
        }
        val db = getOrOpen(name)
        if (db != null) {
            callback(true, null)
        } else {
            callback(null, "Failed to open database '$name'")
        }
    }

    private fun close(name: String, callback: (Any?, String?) -> Unit) {
        requireValidName(name)
        databases.remove(name)?.close()
        callback(null, null)
    }

    // -- Execute (INSERT, UPDATE, DELETE, CREATE TABLE, etc.) --

    private fun execute(name: String, sql: String, params: Array<Any?>, callback: (Any?, String?) -> Unit) {
        val db = getOrOpen(name) ?: run {
            callback(null, "Failed to open database '$name'")
            return
        }

        val stmt = db.compileStatement(sql)
        bindParams(stmt, params)

        val sqlUpper = sql.trimStart().uppercase()
        if (sqlUpper.startsWith("INSERT")) {
            val insertId = stmt.executeInsert()
            callback(mapOf("rowsAffected" to 1, "insertId" to insertId), null)
        } else {
            val rowsAffected = stmt.executeUpdateDelete()
            callback(mapOf("rowsAffected" to rowsAffected), null)
        }
    }

    // -- Query (SELECT) --

    private fun query(name: String, sql: String, params: Array<String?>, callback: (Any?, String?) -> Unit) {
        val db = getOrOpen(name) ?: run {
            callback(null, "Failed to open database '$name'")
            return
        }

        val cursor = db.rawQuery(sql, params)
        val rows = mutableListOf<Map<String, Any?>>()

        cursor.use { c ->
            val columnNames = c.columnNames
            while (c.moveToNext()) {
                val row = mutableMapOf<String, Any?>()
                for (i in columnNames.indices) {
                    row[columnNames[i]] = cursorValue(c, i)
                }
                rows.add(row)
            }
        }

        callback(rows, null)
    }

    // -- Transaction --

    private fun executeTransaction(name: String, statements: List<*>, callback: (Any?, String?) -> Unit) {
        val db = getOrOpen(name) ?: run {
            callback(null, "Failed to open database '$name'")
            return
        }

        db.beginTransaction()
        try {
            val results = mutableListOf<Map<String, Any>>()

            for (raw in statements) {
                val stmtData = toStringKeyMap(raw) ?: continue
                val sql = stmtData["sql"]?.toString() ?: continue
                val params = toParamArray(stmtData["params"])

                val stmt = db.compileStatement(sql)
                bindParams(stmt, params)

                val sqlUpper = sql.trimStart().uppercase()
                if (sqlUpper.startsWith("INSERT")) {
                    val insertId = stmt.executeInsert()
                    results.add(mapOf("rowsAffected" to 1, "insertId" to insertId))
                } else {
                    val rowsAffected = stmt.executeUpdateDelete()
                    results.add(mapOf("rowsAffected" to rowsAffected))
                }
            }

            db.setTransactionSuccessful()
            callback(results, null)
        } catch (e: Exception) {
            callback(null, "Transaction error: ${e.message}")
        } finally {
            db.endTransaction()
        }
    }

    // -- Helpers --

    private fun getOrOpen(name: String): SQLiteDatabase? {
        databases[name]?.let { return it }
        val ctx = context ?: return null
        // Validate BEFORE the name reaches the file path. Throws
        // IllegalArgumentException, which `invoke` surfaces verbatim.
        requireValidName(name)
        val dbDir = File(ctx.filesDir, "databases")
        if (!dbDir.exists()) dbDir.mkdirs()
        val dbPath = File(dbDir, "$name.sqlite").absolutePath
        val db = SQLiteDatabase.openOrCreateDatabase(dbPath, null)
        // Enable WAL mode
        db.enableWriteAheadLogging()
        databases[name] = db
        return db
    }

    private fun bindParams(stmt: android.database.sqlite.SQLiteStatement, params: Array<Any?>) {
        for (i in params.indices) {
            val idx = i + 1 // SQLite params are 1-indexed
            val param = params[i]
            when (param) {
                null -> stmt.bindNull(idx)
                is String -> stmt.bindString(idx, param)
                is Int -> stmt.bindLong(idx, param.toLong())
                is Long -> stmt.bindLong(idx, param)
                is Double -> stmt.bindDouble(idx, param)
                is Float -> stmt.bindDouble(idx, param.toDouble())
                is Boolean -> stmt.bindLong(idx, if (param) 1L else 0L)
                is ByteArray -> stmt.bindBlob(idx, param)
                else -> stmt.bindString(idx, param.toString())
            }
        }
    }

    private fun cursorValue(cursor: Cursor, index: Int): Any? {
        return when (cursor.getType(index)) {
            Cursor.FIELD_TYPE_NULL -> null
            Cursor.FIELD_TYPE_INTEGER -> cursor.getLong(index)
            Cursor.FIELD_TYPE_FLOAT -> cursor.getDouble(index)
            Cursor.FIELD_TYPE_STRING -> cursor.getString(index)
            Cursor.FIELD_TYPE_BLOB -> android.util.Base64.encodeToString(
                cursor.getBlob(index), android.util.Base64.NO_WRAP
            )
            else -> null
        }
    }

    private fun toParamArray(value: Any?): Array<Any?> {
        val list = value as? List<*> ?: return emptyArray()
        return list.toTypedArray()
    }

    private fun toStringArray(value: Any?): Array<String?> {
        val list = value as? List<*> ?: return emptyArray()
        return list.map { it?.toString() }.toTypedArray()
    }

    @Suppress("UNCHECKED_CAST")
    private fun toStringKeyMap(value: Any?): Map<String, Any?>? {
        val map = value as? Map<*, *> ?: return null
        return map as Map<String, Any?>
    }
}
