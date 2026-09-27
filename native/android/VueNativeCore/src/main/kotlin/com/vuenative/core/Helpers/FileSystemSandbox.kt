package com.vuenative.core

import android.content.Context
import java.io.File
import java.io.IOException
import okhttp3.HttpUrl

/**
 * Confinement authority for every path handed to [FileSystemModule] by JavaScript.
 *
 * ## Why this exists
 *
 * The JS bundle is untrusted in the worst case: a malicious OTA update, a
 * compromised npm dependency, or a message injected through `VWebView` all get
 * to execute once with full native-module privileges. Before this guard,
 * `FileSystem` accepted arbitrary absolute paths with no canonicalisation, no
 * symlink resolution and no root confinement, so attacker-controlled JS could
 * read, write and delete anywhere the app UID reaches — including
 * `deleteRecursively()` on a directory it did not own.
 *
 * The concrete escalation was writing `<filesDir>/VueNativeOTA/bundle-<sha>.js`,
 * which — combined with the matching SharedPreferences keys — gave persistent
 * code execution at the next launch and bypassed OTA signature verification
 * entirely. Confinement alone does not close that, because the OTA store
 * legitimately lives inside `filesDir`, so [resolve] denies it explicitly too.
 *
 * ## Rules
 *
 * 1. Paths are trimmed; an empty path is rejected.
 * 2. A relative path is resolved against `filesDir`.
 * 3. The result is canonicalised, which collapses `..` segments and resolves
 *    symlinks. A symlink that points outside the sandbox therefore resolves to a
 *    path outside it and is rejected by rule 5 — it cannot be used to escape.
 * 4. Reserved framework directories are denied.
 * 5. The canonical path must be inside one of the resolved sandbox roots.
 *
 * Rejections are always surfaced as [IllegalArgumentException]. Nothing here
 * falls back silently to "use the raw path anyway".
 */
object FileSystemSandbox {

    /** Default byte cap for `FileSystem.downloadFile` (25 MiB). */
    const val DEFAULT_MAX_DOWNLOAD_BYTES: Long = 25L * 1024 * 1024

    /** Directory name of the OTA bundle store, relative to `filesDir`. */
    internal const val RESERVED_OTA_DIRECTORY = "VueNativeOTA"

    /**
     * Upper bound on bytes `downloadFile` will accept.
     *
     * Host-configurable only. Exposing this to JavaScript would let a
     * compromised bundle exhaust storage on demand.
     */
    @Volatile
    var maxDownloadBytes: Long = DEFAULT_MAX_DOWNLOAD_BYTES

    /**
     * When `false` (the default) `downloadFile` requires HTTPS. Loopback hosts
     * are always permitted so local dev servers and test fixtures keep working.
     *
     * Host-configurable only.
     */
    @Volatile
    var allowInsecureDownloads: Boolean = false

    /** Canonicalised sandbox roots the app is allowed to touch. */
    fun allowedRoots(context: Context): List<File> {
        val ctx = context.applicationContext
        val candidates = listOfNotNull(
            ctx.filesDir,
            ctx.cacheDir,
            ctx.codeCacheDir,
            ctx.noBackupFilesDir,
            ctx.getExternalFilesDir(null),
            ctx.externalCacheDir
        )
        return candidates
            .mapNotNull { runCatching { it.canonicalFile }.getOrNull() }
            .distinctBy { it.path }
    }

    /**
     * Resolve and confine a JavaScript-supplied path.
     *
     * @throws IllegalArgumentException when the path is empty, reserved, cannot be
     *   canonicalised, or resolves outside the app sandbox.
     */
    fun resolve(context: Context, path: String): File {
        val trimmed = path.trim()
        if (trimmed.isEmpty()) {
            throw IllegalArgumentException("FileSystem: path is empty")
        }
        val ctx = context.applicationContext
        val rooted = if (trimmed.startsWith("/")) {
            trimmed
        } else {
            File(ctx.filesDir, trimmed).path
        }
        val canonical = try {
            File(rooted).canonicalFile
        } catch (e: IOException) {
            throw IllegalArgumentException("FileSystem: could not resolve path: '$trimmed'")
        }

        val reserved = reservedOtaDirectory(ctx)
        if (reserved != null && isInside(canonical, reserved)) {
            throw IllegalArgumentException("FileSystem: '$trimmed' is a reserved Vue Native directory")
        }

        if (allowedRoots(ctx).any { isInside(canonical, it) }) {
            return canonical
        }
        throw IllegalArgumentException("FileSystem: path escapes the app sandbox: '$trimmed'")
    }

    /** `true` when [path] resolves inside the sandbox and is not reserved. */
    fun isAllowed(context: Context, path: String): Boolean = try {
        resolve(context, path)
        true
    } catch (e: IllegalArgumentException) {
        false
    }

    /**
     * `true` when [file] IS one of the sandbox roots. Deleting a root would
     * remove the entire files/cache tree in a single call.
     */
    fun isSandboxRoot(context: Context, file: File): Boolean {
        val path = runCatching { file.canonicalFile.path }.getOrNull() ?: return false
        return allowedRoots(context).any { it.path == path }
    }

    /**
     * HTTPS is required unless the host opted into insecure downloads. Loopback
     * hosts are always permitted: that traffic never leaves the device, so local
     * dev servers and test fixtures keep working without weakening production.
     * Mirrors `OTAModule.isAllowedEndpoint`.
     */
    fun isSecureDownload(url: HttpUrl): Boolean {
        if (allowInsecureDownloads) return true
        if (url.scheme == "https") return true
        val host = url.host
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    private fun reservedOtaDirectory(context: Context): File? = runCatching {
        File(context.applicationContext.filesDir, RESERVED_OTA_DIRECTORY).canonicalFile
    }.getOrNull()

    private fun isInside(candidate: File, root: File): Boolean =
        candidate.path == root.path || candidate.path.startsWith(root.path + File.separator)
}
