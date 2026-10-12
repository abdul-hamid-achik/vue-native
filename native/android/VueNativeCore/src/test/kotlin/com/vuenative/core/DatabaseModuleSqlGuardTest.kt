package com.vuenative.core

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import java.io.File
import java.util.UUID
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Regression tests for B3-4: `execute`, `query` and `executeTransaction` accept raw
 * SQL, so `ATTACH` (and `VACUUM INTO`) could reach any writable path. The guard
 * rejects those statements before they reach SQLite, including through comments,
 * multi-statement strings and transactions.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DatabaseModuleSqlGuardTest {
    private lateinit var context: Context
    private lateinit var bridge: NativeBridge
    private lateinit var module: DatabaseModule
    private val name = "guard"
    private val rejection = "ATTACH, DETACH and VACUUM INTO are not allowed"

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        bridge = NativeBridge(context)
        module = DatabaseModule().also { it.initialize(context, bridge) }
    }

    @After
    fun tearDown() {
        module.destroy()
        File(context.filesDir, "databases").deleteRecursively()
    }

    @Test
    fun attachIsRejectedThroughExecuteQueryAndTransaction() {
        val attach = "ATTACH DATABASE '${attachTarget()}' AS evil"

        assertEquals(rejection, invoke("execute", listOf(name, attach, emptyList<Any?>())).error)
        assertEquals(rejection, invoke("query", listOf(name, attach, emptyList<Any?>())).error)
        assertEquals(
            rejection,
            invoke("executeTransaction", listOf(name, listOf(mapOf("sql" to attach)))).error,
        )
    }

    @Test
    fun attachIsRejectedEvenWhenHiddenBehindCommentsOrASecondStatement() {
        for (sql in listOf(
            "/* c */ attach '${attachTarget()}' as evil",
            "-- note\n  ATTACH '${attachTarget()}' AS evil",
            "SELECT 1; ATTACH '${attachTarget()}' AS evil",
            "(ATTACH '${attachTarget()}' AS evil)",
            "DETACH evil",
        )) {
            assertEquals("must reject: $sql", rejection, invoke("execute", listOf(name, sql, emptyList<Any?>())).error)
        }
        assertFalse("ATTACH must never create or open the target", attachTarget().exists())
    }

    @Test
    fun keywordsInsideQuotesAndCommentsAreNotStatements() {
        assertNull(invoke("query", listOf(name, "SELECT 'attach'", emptyList<Any?>())).error)
        assertNull(invoke("query", listOf(name, "SELECT \"attach\" AS x", emptyList<Any?>())).error)
        assertNull(invoke("query", listOf(name, "SELECT 1 /* ATTACH */", emptyList<Any?>())).error)
        assertNull(invoke("query", listOf(name, "SELECT 'it''s; ATTACH'", emptyList<Any?>())).error)
    }

    @Test
    fun vacuumIsAllowedButVacuumIntoIsRejected() {
        assertNull(invoke("execute", listOf(name, "VACUUM", emptyList<Any?>())).error)

        assertEquals(
            rejection,
            invoke("execute", listOf(name, "VACUUM INTO '${attachTarget()}'", emptyList<Any?>())).error,
        )
        assertEquals(
            rejection,
            invoke("execute", listOf(name, "vacuum /* x */ into '${attachTarget()}'", emptyList<Any?>())).error,
        )
        assertFalse(attachTarget().exists())
    }

    @Test
    fun rowsAffectedAndInsertIdReportUpdatesDeletesAndInserts() {
        invoke("execute", listOf(name, "CREATE TABLE items (id INTEGER PRIMARY KEY, label TEXT UNIQUE)", emptyList<Any?>()))

        val insert = invoke("execute", listOf(name, "INSERT INTO items (label) VALUES ('a')", emptyList<Any?>()))
        assertEquals(mapOf<String, Any>("rowsAffected" to 1, "insertId" to 1L), insert.result)

        invoke("execute", listOf(name, "INSERT INTO items (label) VALUES ('b')", emptyList<Any?>()))
        val update = invoke("execute", listOf(name, "UPDATE items SET label = label || '!'", emptyList<Any?>()))
        assertEquals(mapOf<String, Any>("rowsAffected" to 2), update.result)

        val delete = invoke("execute", listOf(name, "DELETE FROM items WHERE id = 1", emptyList<Any?>()))
        assertEquals(mapOf<String, Any>("rowsAffected" to 1), delete.result)

        // An ignored duplicate changes no rows, so it must not report one.
        val ignored = invoke("execute", listOf(name, "INSERT OR IGNORE INTO items (label) VALUES ('b!')", emptyList<Any?>()))
        assertEquals(mapOf<String, Any>("rowsAffected" to 0, "insertId" to -1L), ignored.result)
    }

    private fun attachTarget(): File = File(context.filesDir, "attached-${UUID.randomUUID()}.sqlite")

    private fun invoke(method: String, args: List<Any?>): InvocationResult {
        var result: Any? = null
        var error: String? = null
        module.invoke(method, args, bridge) { value, message ->
            result = value
            error = message
        }
        return InvocationResult(result, error)
    }

    private data class InvocationResult(val result: Any?, val error: String?)
}
