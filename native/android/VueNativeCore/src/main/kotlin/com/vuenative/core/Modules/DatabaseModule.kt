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

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context
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
