package com.vuenative.core

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import okhttp3.*
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.security.MessageDigest

/**
 * Native module for Over-The-Air (OTA) JS bundle updates.
 *
 * Methods:
 *   - checkForUpdate(serverUrl) — check for available updates
 *   - downloadUpdate(url, hash) — download a new bundle and verify integrity
 *   - applyUpdate() — swap to downloaded bundle on next launch
 *   - rollback() — revert to the embedded bundle
 *   - getCurrentVersion() — get current bundle version info
 *
 * Events:
 *   - ota:downloadProgress — payload: { progress, bytesDownloaded, totalBytes }
 */
class OTAModule : NativeModule {
    override val moduleName = "OTA"
    private var appContext: Context? = null
    private var bridgeRef: NativeBridge? = null
    private var prefs: SharedPreferences? = null
    private val client = OkHttpClient()

    private val KEY_PREFIX = "vue_native_ota_"
    private val KEY_CURRENT_VERSION = "${KEY_PREFIX}current_version"
    private val KEY_BUNDLE_PATH = "${KEY_PREFIX}bundle_path"
    private val KEY_PREVIOUS_BUNDLE_PATH = "${KEY_PREFIX}previous_bundle_path"
    private val KEY_PREVIOUS_VERSION = "${KEY_PREFIX}previous_version"
    private val KEY_PENDING_BUNDLE_PATH = "${KEY_PREFIX}pending_bundle_path"

    override fun initialize(context: Context, bridge: NativeBridge) {
        appContext = context.applicationContext
        bridgeRef = bridge
        prefs = context.getSharedPreferences("vue_native_ota", Context.MODE_PRIVATE)
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val p = prefs ?: run { callback(null, "OTA not initialized"); return }

        when (method) {
            "checkForUpdate" -> {
                val serverUrl = args.getOrNull(0)?.toString()
                    ?: run { callback(null, "checkForUpdate: missing serverUrl"); return }
                checkForUpdate(serverUrl, p, callback)
            }
            "downloadUpdate" -> {
                val url = args.getOrNull(0)?.toString()
                    ?: run { callback(null, "downloadUpdate: missing url"); return }
                val expectedHash = args.getOrNull(1)?.toString()
                downloadUpdate(url, expectedHash, p, callback)
            }
            "applyUpdate" -> applyUpdate(p, callback)
            "rollback" -> rollback(p, callback)
            "getCurrentVersion" -> getCurrentVersion(p, callback)
            else -> callback(null, "OTAModule: Unknown method '$method'")
        }
    }

    private fun checkForUpdate(serverUrl: String, prefs: SharedPreferences, callback: (Any?, String?) -> Unit) {
        val currentVersion = prefs.getString(KEY_CURRENT_VERSION, "0") ?: "0"

        val request = Request.Builder()
            .url(serverUrl)
            .header("X-Current-Version", currentVersion)
            .header("X-Platform", "android")
            .header("X-App-Id", appContext?.packageName ?: "unknown")
            .get()
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                callback(null, "Network error: ${e.message}")
            }

            override fun onResponse(call: Call, response: Response) {
                try {
                    val body = response.body?.string() ?: run {
                        callback(null, "Empty response from update server")
                        return
                    }

                    val json = org.json.JSONObject(body)
                    val result = mapOf(
                        "updateAvailable" to (json.optBoolean("updateAvailable", false)),
                        "version" to json.optString("version", ""),
                        "downloadUrl" to json.optString("downloadUrl", ""),
                        "hash" to json.optString("hash", ""),
                        "size" to json.optInt("size", 0),
                        "releaseNotes" to json.optString("releaseNotes", ""),
                    )
                    callback(result, null)
                } catch (e: Exception) {
                    callback(null, "Failed to parse update response: ${e.message}")
                }
            }
        })
    }

    private fun downloadUpdate(
        url: String,
        expectedHash: String?,
        prefs: SharedPreferences,
        callback: (Any?, String?) -> Unit
    ) {
        val request = Request.Builder().url(url).build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                callback(null, "Download failed: ${e.message}")
            }

            override fun onResponse(call: Call, response: Response) {
                try {
                    val body = response.body ?: run {
                        callback(null, "Download failed: empty response")
                        return
                    }

                    val totalBytes = body.contentLength()
                    val ctx = appContext ?: run {
                        callback(null, "Context not available")
                        return
                    }

                    val otaDir = File(ctx.filesDir, "VueNativeOTA")
                    otaDir.mkdirs()
                    val bundleFile = File(otaDir, "bundle.js")

                    val source = body.source()
                    val outputStream = FileOutputStream(bundleFile)
                    val buffer = ByteArray(8192)
                    var bytesDownloaded = 0L

                    while (true) {
                        val read = source.read(buffer)
                        if (read == -1) break
                        outputStream.write(buffer, 0, read)
                        bytesDownloaded += read

                        val progress = if (totalBytes > 0) bytesDownloaded.toDouble() / totalBytes else 0.0
                        bridgeRef?.dispatchGlobalEvent("ota:downloadProgress", mapOf(
                            "progress" to progress,
                            "bytesDownloaded" to bytesDownloaded,
                            "totalBytes" to totalBytes,
                        ))
                    }

                    outputStream.close()
                    source.close()

                    // Verify hash if provided
                    if (!expectedHash.isNullOrEmpty()) {
                        val actualHash = sha256(bundleFile)
                        if (!actualHash.equals(expectedHash, ignoreCase = true)) {
                            bundleFile.delete()
                            callback(null, "Bundle integrity check failed. Expected: $expectedHash, got: $actualHash")
                            return
                        }
                    }

                    prefs.edit().putString(KEY_PENDING_BUNDLE_PATH, bundleFile.absolutePath).apply()

                    callback(mapOf(
                        "path" to bundleFile.absolutePath,
                        "size" to bytesDownloaded,
                    ), null)
                } catch (e: Exception) {
                    callback(null, "Failed to save bundle: ${e.message}")
                }
            }
        })
    }

    private fun applyUpdate(prefs: SharedPreferences, callback: (Any?, String?) -> Unit) {
        val pendingPath = prefs.getString(KEY_PENDING_BUNDLE_PATH, null)
        if (pendingPath == null || !File(pendingPath).exists()) {
            callback(null, "No pending update to apply")
            return
        }

        val editor = prefs.edit()

        // Save current for rollback
        val currentPath = prefs.getString(KEY_BUNDLE_PATH, null)
        val currentVersion = prefs.getString(KEY_CURRENT_VERSION, null)
        if (currentPath != null) editor.putString(KEY_PREVIOUS_BUNDLE_PATH, currentPath)
        if (currentVersion != null) editor.putString(KEY_PREVIOUS_VERSION, currentVersion)

        // Set new bundle as current
        editor.putString(KEY_BUNDLE_PATH, pendingPath)
        editor.remove(KEY_PENDING_BUNDLE_PATH)

        // Increment version
        val version = (prefs.getString(KEY_CURRENT_VERSION, "0")?.toIntOrNull() ?: 0) + 1
        editor.putString(KEY_CURRENT_VERSION, version.toString())

        editor.apply()

        callback(mapOf("applied" to true), null)
    }

    private fun rollback(prefs: SharedPreferences, callback: (Any?, String?) -> Unit) {
        val editor = prefs.edit()
        val previousPath = prefs.getString(KEY_PREVIOUS_BUNDLE_PATH, null)

        if (previousPath != null) {
            editor.putString(KEY_BUNDLE_PATH, previousPath)
            val prevVersion = prefs.getString(KEY_PREVIOUS_VERSION, null)
            if (prevVersion != null) editor.putString(KEY_CURRENT_VERSION, prevVersion)
            editor.remove(KEY_PREVIOUS_BUNDLE_PATH)
            editor.remove(KEY_PREVIOUS_VERSION)
            editor.apply()
            callback(mapOf("rolledBack" to true, "toEmbedded" to false), null)
        } else {
            // Rollback to embedded
            editor.remove(KEY_BUNDLE_PATH)
            editor.remove(KEY_CURRENT_VERSION)
            editor.apply()
            callback(mapOf("rolledBack" to true, "toEmbedded" to true), null)
        }
    }

    private fun getCurrentVersion(prefs: SharedPreferences, callback: (Any?, String?) -> Unit) {
        val version = prefs.getString(KEY_CURRENT_VERSION, "embedded") ?: "embedded"
        val bundlePath = prefs.getString(KEY_BUNDLE_PATH, null)
        val isUsingOTA = bundlePath != null && File(bundlePath).exists()

        callback(mapOf(
            "version" to version,
            "isUsingOTA" to isUsingOTA,
            "bundlePath" to (bundlePath ?: ""),
        ), null)
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(8192)
            while (true) {
                val read = input.read(buffer)
                if (read == -1) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
