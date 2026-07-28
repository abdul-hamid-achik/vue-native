package com.vuenative.core

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import androidx.test.core.app.ApplicationProvider
import java.io.Closeable
import java.io.File
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.URI
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
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

    @Test
    fun rejectsInsecureNonLoopbackHttpEndpoints() {
        val check = invokeAsync("checkForUpdate", listOf("http://example.com/manifest"))
        assertTrue(
            "checkForUpdate must refuse plain HTTP for a public host",
            check.error?.contains("HTTPS", ignoreCase = true) == true,
        )

        val download = invokeAsync(
            "downloadUpdate",
            listOf("http://example.com/bundle.js", "0".repeat(64), "1.0.0"),
        )
        assertTrue(
            "downloadUpdate must refuse plain HTTP for a public host",
            download.error?.contains("HTTPS", ignoreCase = true) == true,
        )
    }

    @Test
    fun localHttpManifestDownloadIntegrityApplyAndRollback() {
        LocalHttpServer().use { server ->
            val firstSource = "globalThis.__otaVersion = 1;".toByteArray()
            val firstHash = OTAModule.sha256(firstSource)
            server.respond("/bundle-1.js", firstSource)
            server.respondJSON(
                "/manifest",
                """{"updateAvailable":true,"version":"1.0.0","downloadUrl":"${server.baseUrl}/bundle-1.js","hash":"$firstHash","size":${firstSource.size},"releaseNotes":"Local fixture"}""",
            )

            val firstCheck = invokeAsync("checkForUpdate", listOf("${server.baseUrl}/manifest"))
            assertNull(firstCheck.error)
            @Suppress("UNCHECKED_CAST")
            val firstManifest = firstCheck.result as Map<String, Any>
            assertEquals("1.0.0", firstManifest["version"])
            assertEquals(firstHash, firstManifest["hash"])
            val initialRequest = server.lastRequest("/manifest")
            assertEquals("embedded", initialRequest?.headers?.get("x-current-version"))
            assertEquals("android", initialRequest?.headers?.get("x-platform"))

            assertNull(
                invokeAsync(
                    "downloadUpdate",
                    listOf("${server.baseUrl}/bundle-1.js", firstHash, "1.0.0"),
                ).error,
            )
            assertNull(invoke("verifyBundle").error)
            assertNull(invoke("applyUpdate").error)
            assertEquals("1.0.0", prefs.getString(OTAModule.KEY_CURRENT_VERSION, null))
            assertTrue(firstSource.contentEquals(OTAModule.activeBundleFile(context)?.readBytes()))

            val secondSource = "globalThis.__otaVersion = 2;".toByteArray()
            val secondHash = OTAModule.sha256(secondSource)
            server.respond("/bundle-2.js", secondSource)
            server.respondJSON(
                "/manifest",
                """{"updateAvailable":true,"version":"2.0.0","downloadUrl":"${server.baseUrl}/bundle-2.js","hash":"$secondHash","size":${secondSource.size}}""",
            )

            assertNull(invokeAsync("checkForUpdate", listOf("${server.baseUrl}/manifest")).error)
            assertEquals("1.0.0", server.lastRequest("/manifest")?.headers?.get("x-current-version"))
            assertNull(
                invokeAsync(
                    "downloadUpdate",
                    listOf("${server.baseUrl}/bundle-2.js", secondHash, "2.0.0"),
                ).error,
            )
            assertNull(invoke("applyUpdate").error)
            assertEquals("2.0.0", prefs.getString(OTAModule.KEY_CURRENT_VERSION, null))

            val rollback = invoke("rollback")
            assertNull(rollback.error)
            @Suppress("UNCHECKED_CAST")
            assertEquals(false, (rollback.result as Map<String, Any>)["toEmbedded"])
            assertEquals("1.0.0", prefs.getString(OTAModule.KEY_CURRENT_VERSION, null))

            val rejectedHash = "0".repeat(64)
            server.respond("/tampered.js", "globalThis.__tampered = true;".toByteArray())
            val rejected = invokeAsync(
                "downloadUpdate",
                listOf("${server.baseUrl}/tampered.js", rejectedHash, "3.0.0"),
            )
            assertTrue(rejected.error?.contains("integrity check failed", ignoreCase = true) == true)
            assertNull(prefs.getString(OTAModule.KEY_PENDING_BUNDLE_PATH, null))
            assertFalse(File(OTAModule.bundleDirectory(context), "bundle-$rejectedHash.js.part").exists())
            assertFalse(File(OTAModule.bundleDirectory(context), "bundle-$rejectedHash.js").exists())
            assertEquals("1.0.0", prefs.getString(OTAModule.KEY_CURRENT_VERSION, null))
        }
    }

    // -------------------------------------------------------------------------
    // ECDSA P-256 publisher signature verification (real crypto vectors)
    // -------------------------------------------------------------------------

    @Test
    fun setVerifyKeyRejectsMalformedKey() {
        val result = invoke("setVerifyKey", listOf("!!!not-base64-der!!!"))
        assertTrue(result.error?.contains("Invalid ECDSA verify key") == true)
    }

    @Test
    fun setVerifyKeyAcceptsValidEcPublicKey() {
        val keyPair = generateEcKeyPair()
        val publicKeyBase64 = Base64.encodeToString(keyPair.public.encoded, Base64.DEFAULT)

        val result = invoke("setVerifyKey", listOf(publicKeyBase64))

        assertNull(result.error)
        @Suppress("UNCHECKED_CAST")
        assertEquals(true, (result.result as Map<String, Any>)["configured"])
    }

    @Test
    fun downloadUpdateAcceptsValidEcdsaSignature() {
        val keyPair = generateEcKeyPair()
        assertNull(invoke("setVerifyKey", listOf(exportPublicKey(keyPair))).error)

        LocalHttpServer().use { server ->
            val source = "globalThis.__signed = true;".toByteArray()
            val hash = OTAModule.sha256(source)
            val signature = sign(source, keyPair)
            server.respond("/signed.js", source)

            val result = invokeAsync(
                "downloadUpdate",
                listOf("${server.baseUrl}/signed.js", hash, "1.0.0", signature),
            )

            assertNull(result.error)
            assertEquals("1.0.0", prefs.getString(OTAModule.KEY_PENDING_VERSION, null))
            assertTrue(File(OTAModule.bundleDirectory(context), "bundle-$hash.js").exists())
        }
    }

    @Test
    fun downloadUpdateRejectsForgedSignature() {
        val keyPair = generateEcKeyPair()
        assertNull(invoke("setVerifyKey", listOf(exportPublicKey(keyPair))).error)

        LocalHttpServer().use { server ->
            val source = "globalThis.__real = true;".toByteArray()
            val hash = OTAModule.sha256(source)
            // Signature is computed over different bytes than the served bundle,
            // so the hash passes but the publisher signature must fail.
            val forgedSignature = sign("globalThis.__attacker = true;".toByteArray(), keyPair)
            server.respond("/forged.js", source)

            val result = invokeAsync(
                "downloadUpdate",
                listOf("${server.baseUrl}/forged.js", hash, "1.0.0", forgedSignature),
            )

            assertTrue(result.error?.contains("signature verification failed") == true)
            assertNull(prefs.getString(OTAModule.KEY_PENDING_BUNDLE_PATH, null))
            assertFalse(File(OTAModule.bundleDirectory(context), "bundle-$hash.js").exists())
        }
    }

    @Test
    fun downloadUpdateRejectsMissingSignatureWhenKeyConfigured() {
        val keyPair = generateEcKeyPair()
        assertNull(invoke("setVerifyKey", listOf(exportPublicKey(keyPair))).error)

        LocalHttpServer().use { server ->
            val source = "globalThis.__unsigned = true;".toByteArray()
            val hash = OTAModule.sha256(source)
            server.respond("/unsigned.js", source)

            val result = invokeAsync(
                "downloadUpdate",
                listOf("${server.baseUrl}/unsigned.js", hash, "1.0.0"),
            )

            assertTrue(result.error?.contains("signature required") == true)
            assertNull(prefs.getString(OTAModule.KEY_PENDING_BUNDLE_PATH, null))
        }
    }

    @Test
    fun downloadUpdateWithoutKeySkipsPublisherAuthentication() {
        // No verify key configured: a download with no signature must still
        // succeed on hash integrity alone (publisher auth is opt-in).
        LocalHttpServer().use { server ->
            val source = "globalThis.__noKey = true;".toByteArray()
            val hash = OTAModule.sha256(source)
            server.respond("/nokey.js", source)

            val result = invokeAsync(
                "downloadUpdate",
                listOf("${server.baseUrl}/nokey.js", hash, "1.0.0"),
            )

            assertNull(result.error)
            assertEquals("1.0.0", prefs.getString(OTAModule.KEY_PENDING_VERSION, null))
        }
    }

    private fun generateEcKeyPair(): KeyPair {
        val generator = KeyPairGenerator.getInstance("EC")
        generator.initialize(ECGenParameterSpec("secp256r1"))
        return generator.generateKeyPair()
    }

    /** Export the public key as base64 DER (X.509/SPKI), matching setVerifyKey. */
    private fun exportPublicKey(keyPair: KeyPair): String =
        Base64.encodeToString(keyPair.public.encoded, Base64.DEFAULT)

    /** Produce a base64 DER SHA256withECDSA signature over [data]. */
    private fun sign(data: ByteArray, keyPair: KeyPair): String {
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(keyPair.private)
        signer.update(data)
        return Base64.encodeToString(signer.sign(), Base64.DEFAULT)
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

    private fun invokeAsync(method: String, args: List<Any?>): InvocationResult {
        val completed = CountDownLatch(1)
        var result: Any? = null
        var error: String? = null
        module.invoke(method, args, bridge) { value, callbackError ->
            result = value
            error = callbackError
            completed.countDown()
        }
        assertTrue("$method callback timed out", completed.await(5, TimeUnit.SECONDS))
        return InvocationResult(result, error)
    }

    private data class StagedBundle(val file: File, val hash: String)
    private data class InvocationResult(val result: Any?, val error: String?)
}

private class LocalHttpServer : Closeable {
    data class Request(val path: String, val headers: Map<String, String>)

    private data class Response(val contentType: String, val body: ByteArray)

    private val responses = ConcurrentHashMap<String, Response>()
    private val requests = CopyOnWriteArrayList<Request>()
    private val executor = Executors.newCachedThreadPool()
    private val server = ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"))
    @Volatile private var closed = false

    val baseUrl = "http://127.0.0.1:${server.localPort}"

    init {
        executor.execute {
            while (!closed) {
                try {
                    val socket = server.accept()
                    executor.execute { respondTo(socket) }
                } catch (error: Exception) {
                    if (!closed) throw error
                }
            }
        }
    }

    fun respond(
        path: String,
        body: ByteArray,
        contentType: String = "application/javascript; charset=utf-8",
    ) {
        responses[path] = Response(contentType, body)
    }

    fun respondJSON(path: String, body: String) {
        respond(path, body.toByteArray(), "application/json")
    }

    fun lastRequest(path: String): Request? = requests.lastOrNull { it.path == path }

    override fun close() {
        closed = true
        server.close()
        executor.shutdownNow()
    }

    private fun respondTo(socket: Socket) {
        socket.use {
            socket.soTimeout = 5_000
            val reader = socket.getInputStream().bufferedReader(Charsets.US_ASCII)
            val requestLine = reader.readLine() ?: return
            val target = requestLine.split(' ').getOrNull(1) ?: "/"
            val headers = mutableMapOf<String, String>()
            while (true) {
                val line = reader.readLine() ?: break
                if (line.isEmpty()) break
                val separator = line.indexOf(':')
                if (separator > 0) {
                    headers[line.substring(0, separator).lowercase()] = line.substring(separator + 1).trim()
                }
            }

            val path = URI(target).path
            requests += Request(path, headers)
            val found = responses[path]
            val response = found ?: Response("text/plain; charset=utf-8", "Not found".toByteArray())
            val status = if (found == null) "404 Not Found" else "200 OK"
            val responseHeaders = buildString {
                append("HTTP/1.1 $status\r\n")
                append("Content-Type: ${response.contentType}\r\n")
                append("Content-Length: ${response.body.size}\r\n")
                append("Connection: close\r\n\r\n")
            }
            socket.getOutputStream().use { output ->
                output.write(responseHeaders.toByteArray(Charsets.US_ASCII))
                output.write(response.body)
                output.flush()
            }
        }
    }
}
