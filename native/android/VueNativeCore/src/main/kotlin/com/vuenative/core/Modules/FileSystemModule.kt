package com.vuenative.core

import android.content.Context
import android.util.Base64
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * Native module providing file system access.
 *
 * ## Path confinement
 *
 * Every path argument is resolved through [FileSystemSandbox] before any I/O.
 * The JavaScript bundle is untrusted in the worst case — a malicious OTA update
 * or a compromised dependency gets to call these methods with full app-UID
 * privileges — so an arbitrary absolute path from JS must never reach [File].
 * Resolution canonicalises the path, resolves symlinks, denies the reserved OTA
 * directory, and rejects anything outside the app's own storage roots.
 * Rejections are surfaced as errors; there is no silent fallback to the raw path.
 */
class FileSystemModule : NativeModule {
    override val moduleName = "FileSystem"
    private var appContext: Context? = null

    // Shares the pin-aware client so configured certificate pins apply to
    // downloads too. Never own or shut down that client's dispatcher.
    private fun httpClient(): OkHttpClient = HttpModule.client()

    override fun initialize(context: Context, bridge: NativeBridge) {
        appContext = context.applicationContext
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        val ctx = appContext
        if (ctx == null) {
            callback(null, "FileSystem not initialized")
            return
        }
        when (method) {
            "readFile" -> {
                val path = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "readFile: missing path")
                        return
                    }
                val file = resolve(ctx, path, callback) ?: return
                val encoding = args.getOrNull(1)?.toString() ?: "utf8"
                if (!file.exists()) {
                    callback(null, "readFile: file not found at ${file.path}")
                    return
                }
                try {
                    if (encoding == "base64") {
                        val bytes = file.readBytes()
                        callback(Base64.encodeToString(bytes, Base64.NO_WRAP), null)
                    } else {
                        callback(file.readText(Charsets.UTF_8), null)
                    }
                } catch (e: Exception) {
                    callback(null, "readFile: ${e.message}")
                }
            }
            "writeFile" -> {
                val path = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "writeFile: missing path")
                        return
                    }
                val content = args.getOrNull(1)?.toString()
                    ?: run {
                        callback(null, "writeFile: missing content")
                        return
                    }
                val file = resolve(ctx, path, callback) ?: return
                val encoding = args.getOrNull(2)?.toString() ?: "utf8"
                try {
                    file.parentFile?.mkdirs()
                    if (encoding == "base64") {
                        val bytes = Base64.decode(content, Base64.DEFAULT)
                        file.writeBytes(bytes)
                    } else {
                        file.writeText(content, Charsets.UTF_8)
                    }
                    callback(null, null)
                } catch (e: Exception) {
                    callback(null, "writeFile: ${e.message}")
                }
            }
            "deleteFile" -> {
                val path = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "deleteFile: missing path")
                        return
                    }
                val file = resolve(ctx, path, callback) ?: return
                if (FileSystemSandbox.isSandboxRoot(ctx, file)) {
                    callback(null, "FileSystem: refusing to delete a sandbox root directory")
                    return
                }
                if (!file.exists()) {
                    callback(null, "deleteFile: file not found at ${file.path}")
                    return
                }
                try {
                    if (file.isDirectory) {
                        file.deleteRecursively()
                    } else {
                        file.delete()
                    }
                    callback(null, null)
                } catch (e: Exception) {
                    callback(null, "deleteFile: ${e.message}")
                }
            }
            "exists" -> {
                val path = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "exists: missing path")
                        return
                    }
                val file = resolve(ctx, path, callback) ?: return
                callback(file.exists(), null)
            }
            "listDirectory" -> {
                val path = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "listDirectory: missing path")
                        return
                    }
                val dir = resolve(ctx, path, callback) ?: return
                if (!dir.exists() || !dir.isDirectory) {
                    callback(null, "listDirectory: not a directory at ${dir.path}")
                    return
                }
                callback(dir.list()?.toList() ?: emptyList<String>(), null)
            }
            "downloadFile" -> {
                val url = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "downloadFile: missing url")
                        return
                    }
                val destPath = args.getOrNull(1)?.toString()
                    ?: run {
                        callback(null, "downloadFile: missing destPath")
                        return
                    }
                val httpUrl = url.toHttpUrlOrNull()
                // `toHttpUrlOrNull` only accepts http/https, so a null result
                // covers `file:`, `javascript:`, `content:` and plain garbage.
                // One clear rejection for all of them: no scheme allowlisting by
                // trial and error, and no silent fallback.
                if (httpUrl == null || !FileSystemSandbox.isSecureDownload(httpUrl)) {
                    callback(null, "downloadFile: refusing non-HTTPS URL: $url")
                    return
                }
                val destination = resolve(ctx, destPath, callback) ?: return
                downloadFile(httpUrl, destination, callback)
            }
            "getDocumentsPath" -> callback(ctx.filesDir.absolutePath, null)
            "getCachesPath" -> callback(ctx.cacheDir.absolutePath, null)
            "stat" -> {
                val path = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "stat: missing path")
                        return
                    }
                val file = resolve(ctx, path, callback) ?: return
                if (!file.exists()) {
                    callback(null, "stat: file not found at ${file.path}")
                    return
                }
                callback(
                    mapOf(
                        "size" to file.length(),
                        "isDirectory" to file.isDirectory,
                        "modified" to file.lastModified()
                    ),
                    null
                )
            }
            "mkdir" -> {
                val path = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "mkdir: missing path")
                        return
                    }
                val dir = resolve(ctx, path, callback) ?: return
                if (dir.mkdirs() || dir.exists()) {
                    callback(null, null)
                } else {
                    callback(null, "mkdir: could not create directory at ${dir.path}")
                }
            }
            "copyFile" -> {
                val srcPath = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "copyFile: missing srcPath")
                        return
                    }
                val destPath = args.getOrNull(1)?.toString()
                    ?: run {
                        callback(null, "copyFile: missing destPath")
                        return
                    }
                val src = resolve(ctx, srcPath, callback) ?: return
                val dest = resolve(ctx, destPath, callback) ?: return
                try {
                    dest.parentFile?.mkdirs()
                    src.copyTo(dest, overwrite = true)
                    callback(null, null)
                } catch (e: Exception) {
                    callback(null, "copyFile: ${e.message}")
                }
            }
            "moveFile" -> {
                val srcPath = args.getOrNull(0)?.toString()
                    ?: run {
                        callback(null, "moveFile: missing srcPath")
                        return
                    }
                val destPath = args.getOrNull(1)?.toString()
                    ?: run {
                        callback(null, "moveFile: missing destPath")
                        return
                    }
                val src = resolve(ctx, srcPath, callback) ?: return
                val dest = resolve(ctx, destPath, callback) ?: return
                try {
                    dest.parentFile?.mkdirs()
                    src.copyTo(dest, overwrite = true)
                    src.delete()
                    callback(null, null)
                } catch (e: Exception) {
                    callback(null, "moveFile: ${e.message}")
                }
            }
            else -> callback(null, "Unknown method: $method")
        }
    }

    /**
     * Resolve a JavaScript-supplied path through the sandbox, reporting the
     * rejection reason to JS when it is not allowed.
     */
    private fun resolve(
        context: Context,
        path: String,
        callback: (Any?, String?) -> Unit
    ): File? = try {
        FileSystemSandbox.resolve(context, path)
    } catch (e: IllegalArgumentException) {
        callback(null, e.message)
        null
    }

    /**
     * Stream a remote body to disk under a byte cap.
     *
     * Written incrementally to a `.part` file rather than buffered in memory with
     * `response.body.bytes()`, and aborted as soon as it exceeds
     * [FileSystemSandbox.maxDownloadBytes].
     */
    private fun downloadFile(
        url: HttpUrl,
        destination: File,
        callback: (Any?, String?) -> Unit
    ) {
        val limit = FileSystemSandbox.maxDownloadBytes
        val request = Request.Builder().url(url).build()
        httpClient().newCall(request).enqueue(object : okhttp3.Callback {
            override fun onFailure(call: okhttp3.Call, e: IOException) {
                callback(null, "downloadFile: ${e.message}")
            }

            override fun onResponse(call: okhttp3.Call, response: okhttp3.Response) {
                response.use {
                    if (!response.isSuccessful) {
                        callback(null, "downloadFile: server returned HTTP ${response.code}")
                        return
                    }
                    val body = response.body
                    if (body == null) {
                        callback(null, "downloadFile: empty response")
                        return
                    }
                    // Reject up front when the server declares an oversized body;
                    // the streaming loop below catches a server that lies.
                    if (body.contentLength() > limit) {
                        callback(null, "downloadFile: response exceeds the $limit byte limit")
                        return
                    }
                    destination.parentFile?.mkdirs()
                    val partial = File(destination.parentFile, destination.name + ".part")
                    try {
                        var written = 0L
                        body.byteStream().use { input ->
                            FileOutputStream(partial).use { output ->
                                val buffer = ByteArray(DOWNLOAD_BUFFER_SIZE)
                                while (true) {
                                    val read = input.read(buffer)
                                    if (read == -1) break
                                    written += read
                                    if (written > limit) throw DownloadTooLargeException(limit)
                                    output.write(buffer, 0, read)
                                }
                            }
                        }
                        if (destination.exists()) destination.delete()
                        if (!partial.renameTo(destination)) {
                            partial.copyTo(destination, overwrite = true)
                            partial.delete()
                        }
                        callback(destination.absolutePath, null)
                    } catch (e: DownloadTooLargeException) {
                        partial.delete()
                        callback(null, "downloadFile: response exceeds the ${e.limit} byte limit")
                    } catch (e: Exception) {
                        partial.delete()
                        callback(null, "downloadFile: ${e.message}")
                    }
                }
            }
        })
    }

    private class DownloadTooLargeException(val limit: Long) : IOException("download too large")

    private companion object {
        const val DOWNLOAD_BUFFER_SIZE = 8192
    }
}
