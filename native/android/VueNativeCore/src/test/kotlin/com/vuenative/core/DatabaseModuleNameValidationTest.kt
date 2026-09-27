package com.vuenative.core

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Regression tests for P1-3: the database name is interpolated into a file path,
 * so it must be validated before it reaches the filesystem.
 *
 * Parameter binding was already correct; these tests cover path control only.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DatabaseModuleNameValidationTest {
    private lateinit var context: Context
    private lateinit var bridge: NativeBridge
    private lateinit var module: DatabaseModule

    private val invalidNames = listOf(
        "../evil",
        "../../evil",
        "a/b",
        "/absolute/evil",
        "",
        " ",
        "with space",
        "semi;colon",
        "quote'name",
        "a".repeat(65),
    )

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        bridge = NativeBridge(context)
        module = DatabaseModule().also { it.initialize(context, bridge) }
    }

    @After
    fun tearDown() {
        module.destroy()
    }

    @Test
    fun invalidNamesAreRejectedForEveryMethod() {
        for (name in invalidNames) {
            val expected = "Invalid database name '$name'; " +
                "expected 1-64 characters of A-Z, a-z, 0-9, underscore, or hyphen"

            val open = invoke("open", listOf<Any?>(name))
            assertNull("open accepted '$name'", open.result)
            assertEquals("open: $name", expected, open.error)

            val close = invoke("close", listOf<Any?>(name))
            assertNull("close accepted '$name'", close.result)
            assertEquals("close: $name", expected, close.error)

            val execute = invoke("execute", listOf<Any?>(name, "SELECT 1", emptyList<Any?>()))
            assertNull("execute accepted '$name'", execute.result)
            assertEquals("execute: $name", expected, execute.error)

            val query = invoke("query", listOf<Any?>(name, "SELECT 1", emptyList<Any?>()))
            assertNull("query accepted '$name'", query.result)
            assertEquals("query: $name", expected, query.error)

            val transaction = invoke(
                "executeTransaction",
                listOf<Any?>(name, listOf(mapOf("sql" to "SELECT 1"))),
            )
            assertNull("executeTransaction accepted '$name'", transaction.result)
            assertEquals("executeTransaction: $name", expected, transaction.error)
        }
    }

    @Test
    fun traversalNeverCreatesAFileOutsideTheDatabaseDirectory() {
        invoke("open", listOf<Any?>("../../evil"))
        invoke("execute", listOf<Any?>("../../evil", "CREATE TABLE t (id INTEGER)", emptyList<Any?>()))

        val databasesDir = File(context.filesDir, "databases")
        assertFalse(File(context.filesDir, "evil.sqlite").exists())
        assertFalse(File(context.filesDir.parentFile, "evil.sqlite").exists())
        assertFalse(File(databasesDir, "evil.sqlite").exists())
    }

    @Test
    fun validNamesStillWorkEndToEnd() {
        for (name in listOf("default", "my-app_1", "A9", "z".repeat(64))) {
            assertNull("open rejected '$name'", invoke("open", listOf<Any?>(name)).error)
            val create = invoke(
                "execute",
                listOf<Any?>(name, "CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY, label TEXT)", emptyList<Any?>()),
            )
            assertNull("create table failed for '$name': ${create.error}", create.error)

            val insert = invoke(
                "execute",
                listOf<Any?>(name, "INSERT INTO items (label) VALUES (?)", listOf<Any?>("alpha")),
            )
            assertNull("insert failed for '$name': ${insert.error}", insert.error)

            val rows = invoke("query", listOf<Any?>(name, "SELECT label FROM items", emptyList<Any?>()))
            @Suppress("UNCHECKED_CAST")
            val first = (rows.result as? List<Map<String, Any?>>)?.firstOrNull()
            assertEquals("alpha", first?.get("label"))

            assertTrue(
                "'$name' should be stored as <name>.sqlite inside the databases directory",
                File(File(context.filesDir, "databases"), "$name.sqlite").exists(),
            )
            assertNull(invoke("close", listOf<Any?>(name)).error)
        }
    }

    @Test
    fun defaultNameIsAcceptedWhenOmitted() {
        assertNull(invoke("open", emptyList()).error)
        assertTrue(File(File(context.filesDir, "databases"), "default.sqlite").exists())
    }

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
