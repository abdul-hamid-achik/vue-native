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
 * Wiring tests proving [FileSystemModule] routes every path argument through
 * [FileSystemSandbox]. The sandbox rules themselves are covered by
 * [FileSystemSandboxTest]; these assert the module does not bypass them, and
 * that legitimate in-sandbox storage still works.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class FileSystemModuleTest {
    private lateinit var context: Context
    private lateinit var bridge: NativeBridge
    private lateinit var module: FileSystemModule
    private lateinit var scratch: File

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        bridge = NativeBridge(context)
        module = FileSystemModule().also { it.initialize(context, bridge) }
        scratch = File(context.cacheDir, "vuenative-fs-${System.nanoTime()}").also { it.mkdirs() }
        FileSystemSandbox.maxDownloadBytes = FileSystemSandbox.DEFAULT_MAX_DOWNLOAD_BYTES
        FileSystemSandbox.allowInsecureDownloads = false
    }

    @After
    fun tearDown() {
        scratch.deleteRecursively()
        FileSystemSandbox.maxDownloadBytes = FileSystemSandbox.DEFAULT_MAX_DOWNLOAD_BYTES
        FileSystemSandbox.allowInsecureDownloads = false
    }

    // -- Rejections --

    @Test
    fun everySinglePathMethodRejectsTraversal() {
        val expected = "FileSystem: path escapes the app sandbox: '../../etc/passwd'"
        for (method in listOf("readFile", "deleteFile", "listDirectory", "stat", "exists", "mkdir")) {
            val response = invoke(method, listOf<Any?>("../../etc/passwd"))
            assertNull("$method should reject a traversal path", response.result)
            assertEquals("$method produced an unexpected rejection", expected, response.error)
        }
    }

    @Test
    fun writeRejectsTraversalOutsideTheSandbox() {
        val response = invoke("writeFile", listOf<Any?>("../../etc/passwd", "owned"))
        assertNull(response.result)
        assertTrue(response.error?.contains("escapes the app sandbox") == true)
    }

    @Test
    fun copyAndMoveRejectEscapingSourceAndDestination() {
        val inside = File(scratch, "payload.txt").absolutePath
        assertNull(invoke("writeFile", listOf<Any?>(inside, "data")).error)

        val escapingDestination = invoke("copyFile", listOf<Any?>(inside, "/etc/vuenative-copy"))
        assertNull(escapingDestination.result)
        assertTrue(escapingDestination.error?.contains("escapes the app sandbox") == true)

        val escapingSource = invoke("moveFile", listOf<Any?>("/etc/passwd", inside))
        assertNull(escapingSource.result)
        assertTrue(escapingSource.error?.contains("escapes the app sandbox") == true)

        assertFalse(File("/etc/vuenative-copy").exists())
    }

    @Test
    fun deleteFileRefusesSandboxRoot() {
        val response = invoke("deleteFile", listOf<Any?>(context.filesDir.absolutePath))
        assertNull(response.result)
        assertEquals("FileSystem: refusing to delete a sandbox root directory", response.error)
        assertTrue(context.filesDir.exists())
    }

    @Test
    fun deleteFileRefusesTheReservedOtaDirectory() {
        val reserved = File(context.filesDir, "VueNativeOTA/bundle-deadbeef.js")
        val response = invoke("deleteFile", listOf<Any?>(reserved.absolutePath))
        assertNull(response.result)
        assertTrue(response.error?.contains("reserved Vue Native directory") == true)
    }

    @Test
    fun downloadFileRejectsInsecureAndUnparseableUrls() {
        val destination = File(scratch, "download.bin").absolutePath

        val http = invoke("downloadFile", listOf<Any?>("http://example.com/a.bin", destination))
        assertNull(http.result)
        assertEquals("downloadFile: refusing non-HTTPS URL: http://example.com/a.bin", http.error)

        val fileScheme = invoke("downloadFile", listOf<Any?>("file:///etc/passwd", destination))
        assertNull(fileScheme.result)
        assertTrue(fileScheme.error?.contains("refusing non-HTTPS URL") == true)

        val notAUrl = invoke("downloadFile", listOf<Any?>("not a url", destination))
        assertNull(notAUrl.result)
        assertEquals("downloadFile: refusing non-HTTPS URL: not a url", notAUrl.error)

        val escaping = invoke("downloadFile", listOf<Any?>("https://example.com/a.bin", "/etc/a.bin"))
        assertNull(escaping.result)
        assertTrue(escaping.error?.contains("escapes the app sandbox") == true)

        assertFalse(File(destination).exists())
    }

    // -- Legitimate in-sandbox use --

    @Test
    fun readWriteRoundTripsInsideTheSandbox() {
        val path = File(scratch, "notes/child.txt").absolutePath

        assertNull(invoke("writeFile", listOf<Any?>(path, "hello")).error)
        assertEquals(true, invoke("exists", listOf<Any?>(path)).result)
        assertEquals("hello", invoke("readFile", listOf<Any?>(path)).result)

        @Suppress("UNCHECKED_CAST")
        val stat = invoke("stat", listOf<Any?>(path)).result as Map<String, Any>
        assertEquals(5L, stat["size"])
        assertEquals(false, stat["isDirectory"])

        val copied = File(scratch, "copy.txt").absolutePath
        assertNull(invoke("copyFile", listOf<Any?>(path, copied)).error)
        assertEquals("hello", invoke("readFile", listOf<Any?>(copied)).result)

        val moved = File(scratch, "moved.txt").absolutePath
        assertNull(invoke("moveFile", listOf<Any?>(copied, moved)).error)
        assertEquals(false, invoke("exists", listOf<Any?>(copied)).result)
        assertEquals("hello", invoke("readFile", listOf<Any?>(moved)).result)

        assertNull(invoke("deleteFile", listOf<Any?>(moved)).error)
        assertEquals(false, invoke("exists", listOf<Any?>(moved)).result)
    }

    @Test
    fun base64RoundTripAndDirectoryListing() {
        val directory = File(scratch, "listing").absolutePath
        assertNull(invoke("mkdir", listOf<Any?>(directory)).error)

        val path = File(directory, "binary.bin").absolutePath
        val encoded = android.util.Base64.encodeToString(
            byteArrayOf(0, -1, 16),
            android.util.Base64.NO_WRAP,
        )
        assertNull(invoke("writeFile", listOf<Any?>(path, encoded, "base64")).error)
        assertEquals(encoded, invoke("readFile", listOf<Any?>(path, "base64")).result)

        @Suppress("UNCHECKED_CAST")
        val listing = invoke("listDirectory", listOf<Any?>(directory)).result as List<String>
        assertEquals(listOf("binary.bin"), listing)
    }

    @Test
    fun deleteFileRemovesAConfinedDirectoryRecursively() {
        val directory = File(scratch, "tree").absolutePath
        assertNull(invoke("mkdir", listOf<Any?>(directory)).error)
        assertNull(invoke("writeFile", listOf<Any?>(File(directory, "a.txt").absolutePath, "a")).error)

        assertNull(invoke("deleteFile", listOf<Any?>(directory)).error)
        assertFalse(File(directory).exists())
    }

    @Test
    fun documentAndCachePathsAreInsideTheSandbox() {
        for (method in listOf("getDocumentsPath", "getCachesPath")) {
            val path = invoke(method, emptyList()).result as? String
            assertNull("$method should not fail", invoke(method, emptyList()).error)
            assertTrue(
                "$method returned a path outside the sandbox: $path",
                FileSystemSandbox.isAllowed(context, path!!),
            )
        }
    }

    // -- Directory copy and move --

    @Test
    fun copyFileCopiesADirectoryTreeWithItsContents() {
        val tree = directoryTree()
        val copied = File(scratch, "copied")

        assertNull(invoke("copyFile", listOf<Any?>(tree.absolutePath, copied.absolutePath)).error)

        assertEquals("alpha", File(copied, "a.txt").readText())
        assertEquals("beta", File(copied, "nested/b.txt").readText())
        assertTrue("a copy must leave the source tree in place", File(tree, "nested/b.txt").exists())
    }

    @Test
    fun moveFileMovesADirectoryTreeWithItsContents() {
        val tree = directoryTree()
        val moved = File(scratch, "moved")

        assertNull(invoke("moveFile", listOf<Any?>(tree.absolutePath, moved.absolutePath)).error)

        assertEquals("alpha", File(moved, "a.txt").readText())
        assertEquals("beta", File(moved, "nested/b.txt").readText())
        assertFalse("a move must remove the source", tree.exists())
    }

    @Test
    fun copyAndMoveRefuseSandboxRootsAndTheOtaAncestor() {
        val inside = File(scratch, "payload.txt").also { it.writeText("data") }
        val filesRoot = context.filesDir.canonicalPath
        val cacheRoot = context.cacheDir.canonicalPath

        // filesDir is a sandbox root and an ancestor of the reserved OTA store.
        val copyFilesRoot = invoke("copyFile", listOf<Any?>(filesRoot, File(scratch, "copy").path))
        assertTrue(copyFilesRoot.error?.contains("ancestor of the reserved OTA directory") == true)

        assertEquals(
            "moveFile: refusing to touch a sandbox root directory",
            invoke("moveFile", listOf<Any?>(cacheRoot, File(scratch, "moved").path)).error,
        )
        assertEquals(
            "copyFile: refusing to touch a sandbox root directory",
            invoke("copyFile", listOf<Any?>(inside.absolutePath, cacheRoot)).error,
        )
        assertTrue("refused operations must not touch the roots", context.cacheDir.isDirectory)
        assertTrue(inside.exists())
    }

    @Test
    fun copyingOrMovingAFileOntoItselfKeepsIt() {
        val file = File(scratch, "same.txt").also { it.writeText("keep") }.absolutePath

        assertNull(invoke("moveFile", listOf<Any?>(file, file)).error)
        assertNull(invoke("copyFile", listOf<Any?>(file, file)).error)
        assertEquals("keep", File(file).readText())
    }

    @Test
    fun aDirectoryCannotBeCopiedOrMovedIntoItself() {
        val tree = File(scratch, "tree").also { File(it, "inner").mkdirs() }
        val into = File(tree, "inner/copy").absolutePath

        assertEquals(
            "copyFile: refusing to copy or move a directory into itself",
            invoke("copyFile", listOf<Any?>(tree.absolutePath, into)).error,
        )
        assertEquals(
            "moveFile: refusing to copy or move a directory into itself",
            invoke("moveFile", listOf<Any?>(tree.absolutePath, into)).error,
        )
        assertTrue(tree.isDirectory)
    }

    @Test
    fun downloadClientNeverFollowsHttpsToHttpRedirects() {
        assertFalse(module.downloadClient().followSslRedirects)
    }

    private fun directoryTree(): File {
        val tree = File(scratch, "tree").also { File(it, "nested").mkdirs() }
        File(tree, "a.txt").writeText("alpha")
        File(tree, "nested/b.txt").writeText("beta")
        return tree
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
