package com.vuenative.core

import android.content.Context
import android.content.SharedPreferences
import androidx.test.core.app.ApplicationProvider
import java.io.File
import java.util.UUID
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

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class OTAModuleTest {
    private lateinit var context: Context
    private lateinit var prefs: SharedPreferences
    private lateinit var bridge: NativeBridge
    private lateinit var module: OTAModule

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        prefs = OTAModule.preferences(context)
        prefs.edit().clear().commit()
        OTAModule.bundleDirectory(context).deleteRecursively()
        bridge = NativeBridge(context)
        module = OTAModule().also { it.initialize(context, bridge) }
    }

    @After
    fun tearDown() {
        module.destroy()
        prefs.edit().clear().commit()
        OTAModule.bundleDirectory(context).deleteRecursively()
    }

    @Test
    fun verifyAndApplyPersistOfferedVersionAndHash() {
        val staged = stageBundle("globalThis.__otaVersion = 2;", "2.4.0")

        val verified = invoke("verifyBundle")
        assertNull(verified.error)
        @Suppress("UNCHECKED_CAST")
        assertEquals("2.4.0", (verified.result as Map<String, Any>)["version"])

        val applied = invoke("applyUpdate")
        assertNull(applied.error)
        assertEquals("2.4.0", prefs.getString(OTAModule.KEY_CURRENT_VERSION, null))
        assertEquals(staged.hash, prefs.getString(OTAModule.KEY_BUNDLE_HASH, null))
        assertEquals(staged.file.canonicalFile, OTAModule.activeBundleFile(context)?.canonicalFile)

        val current = invoke("getCurrentVersion")
        @Suppress("UNCHECKED_CAST")
        val info = current.result as Map<String, Any>
        assertEquals("2.4.0", info["version"])
        assertEquals(true, info["isUsingOTA"])
    }

    @Test
    fun cleanupPartialDownloadRemovesPendingStateAndFile() {
        val staged = stageBundle("globalThis.__pending = true;", "3.0.0")

        val cleaned = invoke("cleanupPartialDownload")

        assertNull(cleaned.error)
        assertFalse(staged.file.exists())
        assertNull(prefs.getString(OTAModule.KEY_PENDING_BUNDLE_PATH, null))
        assertNull(prefs.getString(OTAModule.KEY_PENDING_VERSION, null))
        assertNull(prefs.getString(OTAModule.KEY_PENDING_BUNDLE_HASH, null))
    }

    @Test
    fun activeResolverRejectsTamperedBundleAndClearsAppliedState() {
        val staged = stageBundle("globalThis.__safe = true;", "4.0.0")
        assertNull(invoke("applyUpdate").error)

        staged.file.writeText("globalThis.__tampered = true;")

        assertNull(OTAModule.activeBundleFile(context))
        assertNull(prefs.getString(OTAModule.KEY_BUNDLE_PATH, null))
        assertNull(prefs.getString(OTAModule.KEY_CURRENT_VERSION, null))
        assertNull(prefs.getString(OTAModule.KEY_BUNDLE_HASH, null))
    }

    @Test
    fun rollbackRestoresPreviousContentAddressedBundle() {
        val first = stageBundle("globalThis.__otaVersion = 1;", "1.0.0")
        assertNull(invoke("applyUpdate").error)
        val second = stageBundle("globalThis.__otaVersion = 2;", "2.0.0")
        assertNull(invoke("applyUpdate").error)

        val rolledBack = invoke("rollback")

        assertNull(rolledBack.error)
        @Suppress("UNCHECKED_CAST")
        assertEquals(false, (rolledBack.result as Map<String, Any>)["toEmbedded"])
        assertEquals("1.0.0", prefs.getString(OTAModule.KEY_CURRENT_VERSION, null))
        assertEquals(first.file.canonicalFile, OTAModule.activeBundleFile(context)?.canonicalFile)
        assertTrue(first.file.exists())
        assertFalse(second.file.exists())
    }

    @Test
    fun resolverWillNotReadOrDeleteOutsideManagedDirectory() {
        val source = "globalThis.__outside = true;".toByteArray()
        val outside = File(context.filesDir, "outside-${UUID.randomUUID()}.js")
        outside.writeBytes(source)
        try {
            prefs.edit()
                .putString(OTAModule.KEY_BUNDLE_PATH, outside.absolutePath)
                .putString(OTAModule.KEY_CURRENT_VERSION, "1.0.0")
                .putString(OTAModule.KEY_BUNDLE_HASH, OTAModule.sha256(source))
                .commit()

            assertNull(OTAModule.activeBundleFile(context))
            assertTrue(outside.exists())
        } finally {
            outside.delete()
        }
    }

    @Test
    fun nativeContractRequiresHashAndVersion() {
        val result = invoke("downloadUpdate", listOf("https://example.com/bundle.js", "hash-only"))

        assertTrue(result.error?.contains("url, SHA-256 hash, and version") == true)
    }

    private fun stageBundle(source: String, version: String): StagedBundle {
        val data = source.toByteArray()
        val hash = OTAModule.sha256(data)
        val directory = OTAModule.bundleDirectory(context).also { assertTrue(it.mkdirs() || it.isDirectory) }
        val file = File(directory, "bundle-$hash.js").also { it.writeBytes(data) }
        assertTrue(
            prefs.edit()
                .putString(OTAModule.KEY_PENDING_BUNDLE_PATH, file.absolutePath)
                .putString(OTAModule.KEY_PENDING_VERSION, version)
                .putString(OTAModule.KEY_PENDING_BUNDLE_HASH, hash)
                .commit(),
        )
        return StagedBundle(file, hash)
    }

    private fun invoke(method: String, args: List<Any?> = emptyList()): InvocationResult {
        var result: Any? = null
        var error: String? = null
        module.invoke(method, args, bridge) { value, callbackError ->
            result = value
            error = callbackError
        }
        return InvocationResult(result, error)
    }

    private data class StagedBundle(val file: File, val hash: String)
    private data class InvocationResult(val result: Any?, val error: String?)
}
