package com.vuenative.core

import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.util.Base64
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.security.KeyFactory
import java.security.MessageDigest
import java.security.PublicKey
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response

/**
 * Native module for verified Over-The-Air JavaScript bundle updates.
 *
 * OTA state is persisted as path/version/hash triples. Bundles are content-addressed,
 * so applying a new update never overwrites the one retained for rollback.
 */
class OTAModule : NativeModule {
    override val moduleName = "OTA"

    companion object {
        private const val TAG = "VueNative-OTA"

        internal const val PREFS_NAME = "vue_native_ota"
        internal const val KEY_CURRENT_VERSION = "vue_native_ota_current_version"
        internal const val KEY_BUNDLE_PATH = "vue_native_ota_bundle_path"
        internal const val KEY_BUNDLE_HASH = "vue_native_ota_bundle_hash"
        internal const val KEY_PREVIOUS_BUNDLE_PATH = "vue_native_ota_previous_bundle_path"
        internal const val KEY_PREVIOUS_VERSION = "vue_native_ota_previous_version"
        internal const val KEY_PREVIOUS_BUNDLE_HASH = "vue_native_ota_previous_bundle_hash"
        internal const val KEY_PENDING_BUNDLE_PATH = "vue_native_ota_pending_bundle_path"
        internal const val KEY_PENDING_VERSION = "vue_native_ota_pending_version"
        internal const val KEY_PENDING_BUNDLE_HASH = "vue_native_ota_pending_bundle_hash"

        private val SHA256_PATTERN = Regex("^[a-fA-F0-9]{64}$")

        /**
         * AndroidManifest `<meta-data>` key holding the base64 DER (X.509/SPKI)
         * ECDSA P-256 publisher key.
         *
         * The publisher key MUST come from native configuration. It used to be
         * settable from JavaScript via a `setVerifyKey` method and was never
         * persisted natively, which meant JS was by construction the only party
         * that could set it — there was no trust anchor at all. Any code that ran
         * once in the JS context could install its own key, sign its own bundle,
         * and have the ECDSA check pass.
         */
        internal const val META_DATA_PUBLISHER_KEY = "com.vuenative.ota.verifyKey"

        /** Migration error returned to any JavaScript caller of `setVerifyKey`. */
        internal const val SET_VERIFY_KEY_REJECTION =
            "setVerifyKey is not permitted from JavaScript; configure the OTA publisher key natively " +
                "(Info.plist VueNativeOTAVerifyKey on iOS, AndroidManifest meta-data " +
                "com.vuenative.ota.verifyKey on Android, or the host-side configurePublisherKey API)"

        /**
         * Returned when no publisher key is configured. Verification FAILS
         * CLOSED: the previous behaviour accepted a hash-only bundle, which means
         * any party able to serve bytes with a matching SHA-256 — including
         * attacker JS that computed the hash itself — could install code.
         */
        internal const val MISSING_PUBLISHER_KEY =
            "OTA update rejected: no publisher verification key is configured natively; " +
                "refusing to install an unauthenticated bundle"

        @Volatile
        private var hostPublisherKeyBase64: String? = null

        @Volatile
        private var decodedHostKey: PublicKey? = null

        /**
         * Host-only entry point for apps that prefer code over manifest
         * meta-data. Not reachable from JavaScript.
         *
         * @return an error message when the key material is invalid, else null.
         */
        fun configurePublisherKey(base64SPKI: String): String? = try {
            val der = Base64.decode(base64SPKI, Base64.DEFAULT)
            val key = KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(der))
            decodedHostKey = key
            hostPublisherKeyBase64 = base64SPKI
            null
        } catch (error: Exception) {
            "Invalid ECDSA publisher key: ${error.message}"
        }

        /** Test seam for the host-only configuration path. */
        internal fun resetPublisherKeyForTests() {
            hostPublisherKeyBase64 = null
            decodedHostKey = null
        }

        /** Read the publisher key from the host app's manifest meta-data. */
        internal fun manifestPublisherKey(context: Context): String? = try {
            val info = context.applicationContext.packageManager.getApplicationInfo(
                context.applicationContext.packageName,
                PackageManager.GET_META_DATA
            )
            info.metaData?.getString(META_DATA_PUBLISHER_KEY)
        } catch (error: PackageManager.NameNotFoundException) {
            null
        } catch (error: RuntimeException) {
            null
        }

        /**
         * Compare two dotted version strings.
         *
         * Segments that are all ASCII digits on both sides compare numerically
         * (so `1.10.0` > `1.9.0`); any other pair compares lexically. A missing
         * segment counts as `0` numerically and as the empty string lexically.
         *
         * Semver pre-release ordering is deliberately NOT implemented:
         * `1.0.0-a` and `1.0.0-b` compare lexically as whole segments.
         */
        internal fun compareVersions(lhs: String, rhs: String): Int {
            val left = lhs.split(".")
            val right = rhs.split(".")
            for (index in 0 until maxOf(left.size, right.size)) {
                // A missing segment counts as "0", not as the empty string, so
                // `2.0.1` is correctly newer than `2.0` and `2.0` equals `2.0.0`.
                val leftSegment = left.getOrElse(index) { "0" }
                val rightSegment = right.getOrElse(index) { "0" }
                val leftDigits = isNumericSegment(leftSegment)
                val rightDigits = isNumericSegment(rightSegment)
                if (leftDigits && rightDigits) {
                    val leftValue = leftSegment.toLongOrNull() ?: 0L
                    val rightValue = rightSegment.toLongOrNull() ?: 0L
                    if (leftValue != rightValue) {
                        return leftValue.compareTo(rightValue).coerceIn(-1, 1)
                    }
                } else {
                    val leftText = if (leftDigits) "" else leftSegment
                    val rightText = if (rightDigits) "" else rightSegment
                    if (leftText != rightText) {
                        // `String.compareTo` returns a character delta, so
                        // normalise to the sign the contract promises.
                        return leftText.compareTo(rightText).coerceIn(-1, 1)
                    }
                }
            }
            return 0
        }

        /**
         * `true` when [candidate] is strictly newer than the installed version.
         * A null/blank current version means the app is running its embedded
         * bundle, so any candidate is newer.
         */
        internal fun isStrictlyNewer(candidate: String, current: String?): Boolean {
            if (current.isNullOrBlank()) return true
            return compareVersions(candidate, current) > 0
        }

        /** Rejection message for a downgrade attempt. */
        internal fun downgradeMessage(candidate: String, current: String) =
            "OTA update rejected: version '$candidate' is not newer than the installed version '$current'"

        private fun isNumericSegment(segment: String) =
            segment.isNotEmpty() && segment.all { it in '0'..'9' }

        internal fun preferences(context: Context): SharedPreferences =
            context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        internal fun bundleDirectory(context: Context): File =
            File(context.applicationContext.filesDir, "VueNativeOTA")

        /**
         * Resolve the active bundle for host startup. Invalid, missing, unreadable,
         * or hash-mismatched state is cleared so the Activity can use its asset.
         */
        internal fun activeBundleFile(context: Context): File? {
            val prefs = preferences(context)
            val path = prefs.getString(KEY_BUNDLE_PATH, null)
            val version = prefs.getString(KEY_CURRENT_VERSION, null)
            val hash = prefs.getString(KEY_BUNDLE_HASH, null)
            val file = path?.let { managedFile(context, it) }

            if (version.isNullOrBlank() || hash == null || file == null || validationError(file, hash) != null) {
                if (path != null || version != null || hash != null) {
                    clearActiveState(prefs)
                }
                return null
            }
            return file
        }

        internal fun invalidateActiveBundle(context: Context) {
            clearActiveState(preferences(context))
        }

        private fun clearActiveState(prefs: SharedPreferences) {
            prefs.edit()
                .remove(KEY_BUNDLE_PATH)
                .remove(KEY_CURRENT_VERSION)
                .remove(KEY_BUNDLE_HASH)
                .commit()
        }

        private fun clearPreviousState(editor: SharedPreferences.Editor): SharedPreferences.Editor =
            editor
                .remove(KEY_PREVIOUS_BUNDLE_PATH)
                .remove(KEY_PREVIOUS_VERSION)
                .remove(KEY_PREVIOUS_BUNDLE_HASH)

        private fun managedFile(context: Context, path: String): File? = try {
            val directory = bundleDirectory(context).canonicalFile
            val file = File(path).canonicalFile
            file.takeIf { it.parentFile == directory }
        } catch (_: IOException) {
            null
        }

        private fun validationError(file: File, expectedHash: String): String? {
            if (!SHA256_PATTERN.matches(expectedHash)) return "Bundle has no valid SHA-256 hash"
            if (!file.isFile || !file.canRead()) return "Bundle is missing or unreadable"
            val data = try {
                file.readBytes()
            } catch (_: IOException) {
                return "Bundle is missing or unreadable"
            }
            if (data.isEmpty() || !isReadableJavaScript(data)) {
                return "Bundle is empty or is not valid UTF-8 text"
            }
            return if (sha256(data).equals(expectedHash, ignoreCase = true)) {
                null
            } else {
                "Bundle integrity check failed"
            }
        }

        private fun isReadableJavaScript(data: ByteArray): Boolean = try {
            val source = Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(data))
                .toString()
            source.isNotBlank()
        } catch (_: Exception) {
            false
        }

        internal fun sha256(data: ByteArray): String =
            MessageDigest.getInstance("SHA-256")
                .digest(data)
                .joinToString("") { "%02x".format(it) }
    }

    private data class StoredBundle(
        val file: File,
        val version: String,
        val hash: String,
    )

    private var appContext: Context? = null
    private var bridgeRef: NativeBridge? = null
    private var prefs: SharedPreferences? = null

    // OTA is code loading: use the shared pin-aware client. Do not own or
    // shut down that client's dispatcher — other modules share it.
    private fun httpClient(): OkHttpClient = HttpModule.client()
    @Volatile private var destroyed = false

    // ECDSA P-256 publisher key, resolved exclusively from native configuration:
    // `OTAModule.configurePublisherKey(...)` from host code, or the
    // `com.vuenative.ota.verifyKey` AndroidManifest meta-data. When null,
    // verification FAILS CLOSED — see [verifySignature]. Volatile because it is
    // written on the initialize thread and read on the OkHttp callback thread.
    @Volatile private var verifyKey: PublicKey? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        appContext = context.applicationContext
        bridgeRef = bridge
        prefs = preferences(context)
        destroyed = false
        verifyKey = resolvePublisherKey(context)
    }

    /**
     * Resolve the publisher key from native configuration only.
     *
     * A programmatically configured host key wins over the manifest so a host
     * that derives its key at runtime (e.g. from a build constant) is not
     * overridden by a stale manifest entry. Invalid manifest material is logged
     * and treated as "no key", which fails closed rather than silently disabling
     * publisher authentication.
     */
    private fun resolvePublisherKey(context: Context): PublicKey? {
        decodedHostKey?.let { return it }
        val base64 = hostPublisherKeyBase64 ?: manifestPublisherKey(context) ?: return null
        return try {
            val der = Base64.decode(base64, Base64.DEFAULT)
            KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(der))
        } catch (error: Exception) {
            Log.e(TAG, "Configured OTA publisher key could not be decoded; updates will be rejected", error)
            null
        }
    }

    /**
     * The version of the bundle that will actually run at next launch, or null
     * when the app is on its embedded bundle.
     */
    private fun installedVersion(context: Context, prefs: SharedPreferences): String? {
        if (activeBundleFile(context) == null) return null
        return prefs.getString(KEY_CURRENT_VERSION, null)?.trim()?.takeIf { it.isNotEmpty() }
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit,
    ) {
        val preferences = prefs ?: run {
            callback(null, "OTA not initialized")
            return
        }

        when (method) {
            "checkForUpdate" -> {
                val serverUrl = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "checkForUpdate: missing serverUrl")
                        return
                    }
                checkForUpdate(serverUrl, preferences, callback)
            }
            "setVerifyKey" -> {
                // Retained in the dispatch table purely so callers get an
                // actionable migration error instead of "Unknown method". It
                // never installs a key: a key settable by the code it
                // authenticates is not a trust anchor.
                Log.w(TAG, SET_VERIFY_KEY_REJECTION)
                callback(null, SET_VERIFY_KEY_REJECTION)
            }
            "downloadUpdate" -> {
                val url = args.getOrNull(0)?.toString()
                val expectedHash = args.getOrNull(1)?.toString()
                val version = args.getOrNull(2)?.toString()
                val signature = args.getOrNull(3)?.toString()
                if (url == null || expectedHash == null || version == null) {
                    callback(null, "downloadUpdate requires url, SHA-256 hash, and version")
                    return
                }
                downloadUpdate(url, expectedHash, version, signature, preferences, callback)
            }
            "verifyBundle" -> verifyBundle(preferences, callback)
            "cleanupPartialDownload" -> {
                cleanupPendingBundle(preferences, removeFile = true)
                callback(mapOf("cleaned" to true), null)
            }
            "applyUpdate" -> applyUpdate(preferences, callback)
            "rollback" -> rollback(preferences, callback)
            "getCurrentVersion" -> getCurrentVersion(callback)
            else -> callback(null, "OTAModule: Unknown method '$method'")
        }
    }

    /**
     * OTA endpoints must be HTTPS. Plain HTTP is permitted only for loopback
     * hosts (127.0.0.1 / localhost / ::1) so local dev and test fixtures keep
     * working; loopback traffic never leaves the machine and cannot be
     * intercepted, so this does not weaken production security.
     */
    private fun isAllowedEndpoint(url: HttpUrl): Boolean {
        if (url.scheme == "https") return true
        val host = url.host
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    private fun checkForUpdate(
        serverUrl: String,
        prefs: SharedPreferences,
        callback: (Any?, String?) -> Unit,
    ) {
        val context = appContext ?: run {
            callback(null, "OTA not initialized")
            return
        }
        val url = serverUrl.toHttpUrlOrNull()
        if (url == null || !isAllowedEndpoint(url)) {
            callback(null, "OTA requires HTTPS; refusing insecure update server URL: $serverUrl")
            return
        }
        val currentVersion = if (activeBundleFile(context) == null) {
            "embedded"
        } else {
            prefs.getString(KEY_CURRENT_VERSION, "embedded") ?: "embedded"
        }
        val request = Request.Builder()
            .url(url)
            .header("X-Current-Version", currentVersion)
            .header("X-Platform", "android")
            .header("X-App-Id", context.packageName)
            .get()
            .build()

        httpClient().newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                if (!destroyed) callback(null, "Network error: ${e.message}")
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    if (destroyed) return
                    if (!response.isSuccessful) {
                        callback(null, "Update server returned HTTP ${response.code}")
                        return
                    }
                    val body = response.body?.string() ?: run {
                        callback(null, "Empty response from update server")
                        return
                    }

                    try {
                        val json = org.json.JSONObject(body)
                        callback(
                            mapOf(
                                "updateAvailable" to json.optBoolean("updateAvailable", false),
                                "version" to json.optString("version", ""),
                                "downloadUrl" to json.optString("downloadUrl", ""),
                                "hash" to json.optString("hash", ""),
                                "size" to json.optInt("size", 0),
                                "releaseNotes" to json.optString("releaseNotes", ""),
                            ),
                            null,
                        )
                    } catch (error: Exception) {
                        callback(null, "Failed to parse update response: ${error.message}")
                    }
                }
            }
        })
    }

    private fun downloadUpdate(
        url: String,
        expectedHash: String,
        version: String,
        signature: String?,
        prefs: SharedPreferences,
        callback: (Any?, String?) -> Unit,
    ) {
        val context = appContext ?: run {
            callback(null, "OTA not initialized")
            return
        }
        val downloadUrl = url.toHttpUrlOrNull()
        if (downloadUrl == null || !isAllowedEndpoint(downloadUrl)) {
            callback(null, "OTA requires HTTPS; refusing insecure bundle URL: $url")
            return
        }
        val normalizedHash = expectedHash.trim().lowercase()
        if (!SHA256_PATTERN.matches(normalizedHash)) {
            callback(null, "downloadUpdate requires a 64-character SHA-256 hash")
            return
        }
        val normalizedVersion = version.trim()
        if (normalizedVersion.isEmpty()) {
            callback(null, "downloadUpdate requires a non-empty version")
            return
        }

        // Anti-downgrade, checked before spending any bandwidth. Without this an
        // attacker who can serve bytes could reinstall an older, vulnerable
        // bundle whose signature is still valid.
        val installed = installedVersion(context, prefs)
        if (installed != null && !isStrictlyNewer(normalizedVersion, installed)) {
            callback(null, downgradeMessage(normalizedVersion, installed))
            return
        }

        cleanupPendingBundle(prefs, removeFile = true)
        val request = Request.Builder().url(downloadUrl).build()
        httpClient().newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                if (!destroyed) callback(null, "Download failed: ${e.message}")
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    if (destroyed) return
                    if (!response.isSuccessful) {
                        callback(null, "Bundle server returned HTTP ${response.code}")
                        return
                    }
                    val body = response.body ?: run {
                        callback(null, "Download failed: empty response")
                        return
                    }

                    val otaDirectory = bundleDirectory(context)
                    if (!otaDirectory.exists() && !otaDirectory.mkdirs()) {
                        callback(null, "Failed to create OTA bundle directory")
                        return
                    }
                    val destination = File(otaDirectory, "bundle-$normalizedHash.js")
                    val partial = File(otaDirectory, "bundle-$normalizedHash.js.part")

                    try {
                        var bytesDownloaded = 0L
                        body.source().use { source ->
                            FileOutputStream(partial).use { output ->
                                val buffer = ByteArray(8192)
                                while (true) {
                                    val read = source.read(buffer)
                                    if (read == -1) break
                                    output.write(buffer, 0, read)
                                    bytesDownloaded += read

                                    val totalBytes = body.contentLength()
                                    val progress = if (totalBytes > 0) {
                                        bytesDownloaded.toDouble() / totalBytes
                                    } else {
                                        0.0
                                    }
                                    bridgeRef?.dispatchGlobalEvent(
                                        "ota:downloadProgress",
                                        mapOf(
                                            "progress" to progress,
                                            "bytesDownloaded" to bytesDownloaded,
                                            "totalBytes" to totalBytes,
                                        ),
                                    )
                                }
                            }
                        }

                        val validationError = validationError(partial, normalizedHash)
                        if (validationError != null) {
                            partial.delete()
                            callback(null, validationError)
                            return
                        }

                        // Publisher authentication. Runs after the integrity hash
                        // so a corrupt bundle is rejected before we spend time on
                        // signature math; a failure here removes the partial file.
                        val signatureError = verifySignature(partial, signature)
                        if (signatureError != null) {
                            partial.delete()
                            callback(null, signatureError)
                            return
                        }

                        if (destination.exists() && validationError(destination, normalizedHash) == null) {
                            partial.delete()
                        } else {
                            destination.delete()
                            if (!partial.renameTo(destination)) {
                                partial.copyTo(destination, overwrite = true)
                                partial.delete()
                            }
                        }

                        val persisted = prefs.edit()
                            .putString(KEY_PENDING_BUNDLE_PATH, destination.absolutePath)
                            .putString(KEY_PENDING_BUNDLE_HASH, normalizedHash)
                            .putString(KEY_PENDING_VERSION, normalizedVersion)
                            .commit()
                        if (!persisted) {
                            deleteIfUnreferenced(destination, prefs)
                            callback(null, "Failed to persist pending OTA state")
                            return
                        }

                        callback(
                            mapOf(
                                "path" to destination.absolutePath,
                                "size" to bytesDownloaded,
                                "version" to normalizedVersion,
                            ),
                            null,
                        )
                    } catch (error: Exception) {
                        partial.delete()
                        callback(null, "Failed to save bundle: ${error.message}")
                    }
                }
            }
        })
    }

    /**
     * Verify the downloaded bundle's publisher signature.
     *
     * Publisher authentication is MANDATORY:
     * - No publisher key configured natively: FAIL CLOSED and reject. The old
     *   behaviour logged a warning and accepted the bundle on its hash alone,
     *   which only proves the bytes were not corrupted in transit — not who
     *   produced them. Attacker JS can compute a matching SHA-256 for its own
     *   bundle trivially.
     * - Key configured but signature missing/empty: reject.
     * - Key configured and signature present: verify SHA256withECDSA over the
     *   bundle bytes; reject on any failure or mismatch.
     *
     * Returns an error message on rejection, or null when the bundle is accepted.
     */
    private fun verifySignature(bundleFile: File, signature: String?): String? {
        val publicKey = verifyKey
        if (publicKey == null) {
            Log.e(TAG, MISSING_PUBLISHER_KEY)
            return MISSING_PUBLISHER_KEY
        }
        if (signature.isNullOrEmpty()) {
            return "signature required when a verify key is configured"
        }
        return try {
            val bundleBytes = bundleFile.readBytes()
            val verifier = Signature.getInstance("SHA256withECDSA")
            verifier.initVerify(publicKey)
            verifier.update(bundleBytes)
            val valid = verifier.verify(Base64.decode(signature, Base64.DEFAULT))
            if (valid) null else "signature verification failed"
        } catch (error: Exception) {
            "signature verification failed: ${error.message}"
        }
    }

    private fun verifyBundle(prefs: SharedPreferences, callback: (Any?, String?) -> Unit) {
        val (bundle, error) = pendingBundle(prefs)
        if (bundle == null) {
            callback(null, error)
            return
        }
        callback(
            mapOf(
                "verified" to true,
                "version" to bundle.version,
                "path" to bundle.file.absolutePath,
            ),
            null,
        )
    }

    private fun applyUpdate(prefs: SharedPreferences, callback: (Any?, String?) -> Unit) {
        val context = appContext ?: run {
            callback(null, "OTA not initialized")
            return
        }
        val (pending, error) = pendingBundle(prefs)
        if (pending == null) {
            callback(null, error)
            return
        }

        // Authoritative anti-downgrade gate. `downloadUpdate` checks the same
        // rule, but the pending state lives in SharedPreferences and could have
        // been staged by an older build or written directly, so re-check here.
        val installed = installedVersion(context, prefs)
        if (installed != null && !isStrictlyNewer(pending.version, installed)) {
            callback(null, downgradeMessage(pending.version, installed))
            return
        }

        removeSupersededPreviousBundle(prefs)
        val currentFile = activeBundleFile(context)
        val editor = prefs.edit()
        if (currentFile != null) {
            editor
                .putString(KEY_PREVIOUS_BUNDLE_PATH, currentFile.absolutePath)
                .putString(KEY_PREVIOUS_VERSION, prefs.getString(KEY_CURRENT_VERSION, null))
                .putString(KEY_PREVIOUS_BUNDLE_HASH, prefs.getString(KEY_BUNDLE_HASH, null))
        } else {
            clearPreviousState(editor)
        }

        editor
            .putString(KEY_BUNDLE_PATH, pending.file.absolutePath)
            .putString(KEY_CURRENT_VERSION, pending.version)
            .putString(KEY_BUNDLE_HASH, pending.hash)
            .remove(KEY_PENDING_BUNDLE_PATH)
            .remove(KEY_PENDING_VERSION)
            .remove(KEY_PENDING_BUNDLE_HASH)

        if (!editor.commit()) {
            callback(null, "Failed to persist applied OTA state")
            return
        }
        callback(mapOf("applied" to true, "version" to pending.version), null)
    }

    private fun rollback(prefs: SharedPreferences, callback: (Any?, String?) -> Unit) {
        val context = appContext ?: run {
            callback(null, "OTA not initialized")
            return
        }
        cleanupPendingBundle(prefs, removeFile = true)
        val oldCurrent = prefs.getString(KEY_BUNDLE_PATH, null)?.let { managedFile(context, it) }
        val previousPath = prefs.getString(KEY_PREVIOUS_BUNDLE_PATH, null)
        val previousVersion = prefs.getString(KEY_PREVIOUS_VERSION, null)
        val previousHash = prefs.getString(KEY_PREVIOUS_BUNDLE_HASH, null)
        val previousFile = previousPath?.let { managedFile(context, it) }
        val restorePrevious = previousFile != null &&
            !previousVersion.isNullOrBlank() &&
            previousHash != null &&
            validationError(previousFile, previousHash) == null

        val editor = prefs.edit()
        if (restorePrevious) {
            editor
                .putString(KEY_BUNDLE_PATH, previousFile?.absolutePath)
                .putString(KEY_CURRENT_VERSION, previousVersion)
                .putString(KEY_BUNDLE_HASH, previousHash?.lowercase())
        } else {
            editor
                .remove(KEY_BUNDLE_PATH)
                .remove(KEY_CURRENT_VERSION)
                .remove(KEY_BUNDLE_HASH)
        }
        clearPreviousState(editor)
        if (!editor.commit()) {
            callback(null, "Failed to persist OTA rollback state")
            return
        }

        if (oldCurrent != null && oldCurrent != previousFile) {
            oldCurrent.delete()
        }
        callback(mapOf("rolledBack" to true, "toEmbedded" to !restorePrevious), null)
    }

    private fun getCurrentVersion(callback: (Any?, String?) -> Unit) {
        val context = appContext ?: run {
            callback(null, "OTA not initialized")
            return
        }
        val file = activeBundleFile(context)
        if (file == null) {
            callback(
                mapOf(
                    "version" to "embedded",
                    "isUsingOTA" to false,
                    "bundlePath" to "",
                ),
                null,
            )
            return
        }

        val preferences = prefs
        callback(
            mapOf(
                "version" to (preferences?.getString(KEY_CURRENT_VERSION, "embedded") ?: "embedded"),
                "isUsingOTA" to true,
                "bundlePath" to file.absolutePath,
            ),
            null,
        )
    }

    private fun pendingBundle(prefs: SharedPreferences): Pair<StoredBundle?, String?> {
        val context = appContext ?: return null to "OTA not initialized"
        val path = prefs.getString(KEY_PENDING_BUNDLE_PATH, null)
            ?: return null to "No pending update to verify"
        val version = prefs.getString(KEY_PENDING_VERSION, null)
            ?: return null to "Pending update has no version"
        val hash = prefs.getString(KEY_PENDING_BUNDLE_HASH, null)
            ?: return null to "Pending update has no SHA-256 hash"
        if (version.isBlank()) return null to "Pending update has no version"
        val file = managedFile(context, path)
            ?: return null to "Pending bundle path is outside the managed OTA directory"
        val error = validationError(file, hash)
        return if (error == null) {
            StoredBundle(file, version, hash.lowercase()) to null
        } else {
            null to error
        }
    }

    private fun cleanupPendingBundle(prefs: SharedPreferences, removeFile: Boolean) {
        val context = appContext
        if (removeFile && context != null) {
            val pendingPath = prefs.getString(KEY_PENDING_BUNDLE_PATH, null)
            val activePath = prefs.getString(KEY_BUNDLE_PATH, null)
            val previousPath = prefs.getString(KEY_PREVIOUS_BUNDLE_PATH, null)
            if (pendingPath != null && pendingPath != activePath && pendingPath != previousPath) {
                managedFile(context, pendingPath)?.delete()
            }
            bundleDirectory(context).listFiles { file -> file.name.endsWith(".part") }
                ?.forEach { it.delete() }
        }
        prefs.edit()
            .remove(KEY_PENDING_BUNDLE_PATH)
            .remove(KEY_PENDING_VERSION)
            .remove(KEY_PENDING_BUNDLE_HASH)
            .commit()
    }

    private fun removeSupersededPreviousBundle(prefs: SharedPreferences) {
        val context = appContext ?: return
        val previousPath = prefs.getString(KEY_PREVIOUS_BUNDLE_PATH, null)
        if (previousPath != null && previousPath != prefs.getString(KEY_BUNDLE_PATH, null)) {
            managedFile(context, previousPath)?.delete()
        }
        clearPreviousState(prefs.edit()).commit()
    }

    private fun deleteIfUnreferenced(file: File, prefs: SharedPreferences) {
        if (file.absolutePath != prefs.getString(KEY_BUNDLE_PATH, null) &&
            file.absolutePath != prefs.getString(KEY_PREVIOUS_BUNDLE_PATH, null)
        ) {
            file.delete()
        }
    }

    override fun destroy() {
        if (destroyed) return
        destroyed = true
        bridgeRef = null
        verifyKey = null
        appContext?.let { context ->
            bundleDirectory(context).listFiles { file -> file.name.endsWith(".part") }
                ?.forEach { it.delete() }
        }
        appContext = null
        prefs = null
    }
}
