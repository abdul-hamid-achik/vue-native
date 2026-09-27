package com.vuenative.core

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import java.io.File
import java.nio.file.Files
import java.nio.file.Paths
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Confinement tests for [FileSystemSandbox] — the regression tests for P0-2.
 *
 * Without confinement, arbitrary JavaScript could read, write and delete
 * anywhere the app UID reached, including the OTA bundle store.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class FileSystemSandboxTest {
    private lateinit var context: Context
    private lateinit var outside: File

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        outside = File(System.getProperty("java.io.tmpdir"), "vuenative-outside-${System.nanoTime()}")
            .also { it.mkdirs() }
    }

    @After
    fun tearDown() {
        outside.deleteRecursively()
        FileSystemSandbox.maxDownloadBytes = FileSystemSandbox.DEFAULT_MAX_DOWNLOAD_BYTES
        FileSystemSandbox.allowInsecureDownloads = false
    }

    // -- Rejections --

    @Test
    fun rejectsAbsoluteTraversalToEtcPasswd() {
        assertRejected("../../etc/passwd", "FileSystem: path escapes the app sandbox: '../../etc/passwd'")
    }

    @Test
    fun rejectsAbsolutePathOutsideEveryRoot() {
        assertRejected("/etc/passwd", "FileSystem: path escapes the app sandbox: '/etc/passwd'")
        assertRejected("/data/data/com.other.app/shared_prefs/x.xml", null)
        assertRejected(outside.absolutePath + "/payload.txt", null)
    }

    @Test
    fun rejectsEmptyAndBlankPath() {
        assertRejected("", "FileSystem: path is empty")
        assertRejected("   \n ", "FileSystem: path is empty")
    }

    @Test
    fun rejectsSymlinkThatEscapesTheSandbox() {
        val link = File(context.filesDir, "escape-link-${System.nanoTime()}")
        try {
            Files.createSymbolicLink(Paths.get(link.absolutePath), Paths.get(outside.absolutePath))
            val through = link.absolutePath + "/passwd"
            val error = captureError(through)
            assertNotNull("a symlink out of the sandbox must be rejected", error)
            assertTrue(
                "expected an escape error, got: $error",
                error!!.contains("escapes the app sandbox")
            )
            assertFalse(FileSystemSandbox.isAllowed(context, through))
        } finally {
            link.delete()
        }
    }

    @Test
    fun rejectsReservedOtaBundleDirectory() {
        val reserved = File(context.filesDir, "VueNativeOTA")
        assertRejected(
            File(reserved, "bundle-deadbeef.js").absolutePath,
            "FileSystem: '${File(reserved, "bundle-deadbeef.js").absolutePath}' " +
                "is a reserved Vue Native directory",
        )
        // The directory itself is reserved too, not only its contents.
        val directoryError = captureError(reserved.absolutePath)
        assertNotNull(directoryError)
        assertTrue(directoryError!!.contains("reserved Vue Native directory"))
    }

    // -- Accepted paths --

    @Test
    fun acceptsPathsInsideEverySandboxRoot() {
        val roots = FileSystemSandbox.allowedRoots(context)
        assertTrue("expected at least filesDir and cacheDir", roots.size >= 2)
        for (root in roots) {
            val candidate = File(root, "vuenative-${System.nanoTime()}.txt").absolutePath
            val resolved = FileSystemSandbox.resolve(context, candidate)
            assertTrue(
                "$resolved should stay inside $root",
                resolved.path == root.path || resolved.path.startsWith(root.path + File.separator)
            )
            assertTrue(FileSystemSandbox.isAllowed(context, candidate))
        }
    }

    @Test
    fun resolvesRelativePathAgainstFilesDir() {
        val resolved = FileSystemSandbox.resolve(context, "notes/child.txt")
        assertEquals(
            File(context.filesDir, "notes/child.txt").canonicalPath,
            resolved.path,
        )
    }

    @Test
    fun resolvesNonExistentPathWithoutFallingBackToTheRawString() {
        val target = File(context.cacheDir, "deep/nested/leaf.txt").absolutePath
        val resolved = FileSystemSandbox.resolve(context, target)
        assertEquals(File(target).canonicalPath, resolved.path)
    }

    @Test
    fun recognisesSandboxRoots() {
        assertTrue(FileSystemSandbox.isSandboxRoot(context, context.filesDir))
        assertTrue(FileSystemSandbox.isSandboxRoot(context, context.cacheDir))
        assertFalse(FileSystemSandbox.isSandboxRoot(context, File(context.filesDir, "child.txt")))
    }

    // -- Downloads --

    @Test
    fun downloadRequiresHttpsByDefault() {
        assertFalse(FileSystemSandbox.allowInsecureDownloads)
        assertTrue(FileSystemSandbox.isSecureDownload("https://example.com/a.bin".toHttpUrlOrNull()!!))
        assertFalse(FileSystemSandbox.isSecureDownload("http://example.com/a.bin".toHttpUrlOrNull()!!))
    }

    @Test
    fun loopbackDownloadsStayAllowedForLocalDevelopment() {
        assertTrue(FileSystemSandbox.isSecureDownload("http://localhost:8080/a.bin".toHttpUrlOrNull()!!))
        assertTrue(FileSystemSandbox.isSecureDownload("http://127.0.0.1/a.bin".toHttpUrlOrNull()!!))
    }

    @Test
    fun hostCanOptIntoInsecureDownloads() {
        FileSystemSandbox.allowInsecureDownloads = true
        assertTrue(FileSystemSandbox.isSecureDownload("http://example.com/a.bin".toHttpUrlOrNull()!!))
    }

    @Test
    fun defaultDownloadCapIs25MiB() {
        assertEquals(25L * 1024 * 1024, FileSystemSandbox.DEFAULT_MAX_DOWNLOAD_BYTES)
        FileSystemSandbox.maxDownloadBytes = 1024
        assertEquals(1024L, FileSystemSandbox.maxDownloadBytes)
    }

    // -- Helpers --

    private fun assertRejected(path: String, expectedMessage: String?) {
        val error = captureError(path)
        assertNotNull("expected '$path' to be rejected", error)
        if (expectedMessage != null) {
            assertEquals(expectedMessage, error)
        }
    }

    private fun captureError(path: String): String? = try {
        FileSystemSandbox.resolve(context, path)
        null
    } catch (e: IllegalArgumentException) {
        e.message
    } catch (e: Exception) {
        fail("expected IllegalArgumentException, got ${e.javaClass.name}: ${e.message}")
        null
    }
}
