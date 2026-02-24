package com.vuenative.core

import android.content.Context
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit
import android.util.Base64

class FileSystemModule : NativeModule {
    override val moduleName = "FileSystem"
    private var appContext: Context? = null

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    override fun initialize(context: Context, bridge: NativeBridge) {
        appContext = context
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "readFile" -> {
                val path = args.getOrNull(0)?.toString()
                    ?: run { callback(null, "readFile: missing path"); return }
                val encoding = args.getOrNull(1)?.toString() ?: "utf8"
                val file = File(path)
                if (!file.exists()) {
                    callback(null, "readFile: file not found at $path"); return
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
                    ?: run { callback(null, "writeFile: missing path"); return }
                val content = args.getOrNull(1)?.toString()
                    ?: run { callback(null, "writeFile: missing content"); return }
                val encoding = args.getOrNull(2)?.toString() ?: "utf8"
                try {
                    val file = File(path)
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
                    ?: run { callback(null, "deleteFile: missing path"); return }
                val file = File(path)
                if (!file.exists()) {
                    callback(null, "deleteFile: file not found at $path"); return
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
                    ?: run { callback(null, "exists: missing path"); return }
                callback(File(path).exists(), null)
            }
            "listDirectory" -> {
                val path = args.getOrNull(0)?.toString()
                    ?: run { callback(null, "listDirectory: missing path"); return }
                val dir = File(path)
                if (!dir.exists() || !dir.isDirectory) {
                    callback(null, "listDirectory: not a directory at $path"); return
                }
                callback(dir.list()?.toList() ?: emptyList<String>(), null)
            }
            "downloadFile" -> {
                val url = args.getOrNull(0)?.toString()
                    ?: run { callback(null, "downloadFile: missing url"); return }
                val destPath = args.getOrNull(1)?.toString()
                    ?: run { callback(null, "downloadFile: missing destPath"); return }
                val request = Request.Builder().url(url).build()
                client.newCall(request).enqueue(object : okhttp3.Callback {
                    override fun onFailure(call: okhttp3.Call, e: IOException) {
                        callback(null, "downloadFile: ${e.message}")
                    }
                    override fun onResponse(call: okhttp3.Call, response: okhttp3.Response) {
                        try {
                            val bytes = response.body?.bytes()
                                ?: run { callback(null, "downloadFile: empty response"); return }
                            val file = File(destPath)
                            file.parentFile?.mkdirs()
                            file.writeBytes(bytes)
                            callback(destPath, null)
                        } catch (e: Exception) {
                            callback(null, "downloadFile: ${e.message}")
                        }
                    }
                })
            }
            "getDocumentsPath" -> {
                val ctx = appContext
                    ?: run { callback(null, "FileSystem not initialized"); return }
                callback(ctx.filesDir.absolutePath, null)
            }
            "getCachesPath" -> {
                val ctx = appContext
                    ?: run { callback(null, "FileSystem not initialized"); return }
                callback(ctx.cacheDir.absolutePath, null)
            }
            "stat" -> {
                val path = args.getOrNull(0)?.toString()
                    ?: run { callback(null, "stat: missing path"); return }
                val file = File(path)
                if (!file.exists()) {
                    callback(null, "stat: file not found at $path"); return
                }
                callback(mapOf(
                    "size" to file.length(),
                    "isDirectory" to file.isDirectory,
                    "modified" to file.lastModified()
                ), null)
            }
            "mkdir" -> {
                val path = args.getOrNull(0)?.toString()
                    ?: run { callback(null, "mkdir: missing path"); return }
                val dir = File(path)
                if (dir.mkdirs() || dir.exists()) {
                    callback(null, null)
                } else {
                    callback(null, "mkdir: could not create directory at $path")
                }
            }
            "copyFile" -> {
                val srcPath = args.getOrNull(0)?.toString()
                    ?: run { callback(null, "copyFile: missing srcPath"); return }
                val destPath = args.getOrNull(1)?.toString()
                    ?: run { callback(null, "copyFile: missing destPath"); return }
                try {
                    val src = File(srcPath)
                    val dest = File(destPath)
                    dest.parentFile?.mkdirs()
                    src.copyTo(dest, overwrite = true)
                    callback(null, null)
                } catch (e: Exception) {
                    callback(null, "copyFile: ${e.message}")
                }
            }
            "moveFile" -> {
                val srcPath = args.getOrNull(0)?.toString()
                    ?: run { callback(null, "moveFile: missing srcPath"); return }
                val destPath = args.getOrNull(1)?.toString()
                    ?: run { callback(null, "moveFile: missing destPath"); return }
                try {
                    val src = File(srcPath)
                    val dest = File(destPath)
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
}
