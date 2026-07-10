package com.vuenative.core

import android.content.Context
import android.content.SharedPreferences
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.security.MessageDigest
import okhttp3.Call
import okhttp3.Callback
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
    private val client = OkHttpClient()
    @Volatile private var destroyed = false

    override fun initialize(context: Context, bridge: NativeBridge) {
        appContext = context.applicationContext
        bridgeRef = bridge
        prefs = preferences(context)
        destroyed = false
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
            "downloadUpdate" -> {
                val url = args.getOrNull(0)?.toString()
                val expectedHash = args.getOrNull(1)?.toString()
                val version = args.getOrNull(2)?.toString()
                if (url == null || expectedHash == null || version == null) {
                    callback(null, "downloadUpdate requires url, SHA-256 hash, and version")
                    return
                }
                downloadUpdate(url, expectedHash, version, preferences, callback)
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

    private fun checkForUpdate(
        serverUrl: String,
        prefs: SharedPreferences,
        callback: (Any?, String?) -> Unit,
    ) {
        val context = appContext ?: run {
            callback(null, "OTA not initialized")
            return
        }
        val url = serverUrl.toHttpUrlOrNull() ?: run {
            callback(null, "Invalid update server URL; expected HTTP or HTTPS")
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

        client.newCall(request).enqueue(object : Callback {
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
        prefs: SharedPreferences,
        callback: (Any?, String?) -> Unit,
    ) {
        val context = appContext ?: run {
            callback(null, "OTA not initialized")
            return
        }
        val downloadUrl = url.toHttpUrlOrNull() ?: run {
            callback(null, "Invalid bundle URL; expected HTTP or HTTPS")
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

        cleanupPendingBundle(prefs, removeFile = true)
        val request = Request.Builder().url(downloadUrl).build()
        client.newCall(request).enqueue(object : Callback {
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
        client.dispatcher.cancelAll()
        client.connectionPool.evictAll()
        client.dispatcher.executorService.shutdown()
        bridgeRef = null
        appContext?.let { context ->
            bundleDirectory(context).listFiles { file -> file.name.endsWith(".part") }
                ?.forEach { it.delete() }
        }
        appContext = null
        prefs = null
    }
}
