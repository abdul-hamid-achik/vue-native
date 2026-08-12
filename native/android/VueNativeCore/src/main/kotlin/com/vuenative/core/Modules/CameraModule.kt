package com.vuenative.core

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.MediaStore
import androidx.core.content.FileProvider
import java.io.File
import java.lang.ref.WeakReference
import java.util.UUID

/**
 * CameraModule — backs the useCamera() composable
 * (`packages/runtime/src/composables/useCamera.ts`).
 *
 * Mirrors the Activity-result pattern already used by [ImagePickerModule]:
 * a process-wide [WeakReference] to the current Activity plus a single
 * in-flight callback, populated by [VueNativeActivity] in `onCreate`/`onDestroy`
 * and resolved by `onActivityResult`.
 *
 * Methods:
 *   - launchCamera(options)       -- photo capture via ACTION_IMAGE_CAPTURE
 *   - launchImageLibrary(options) -- photo picker (shares [ImagePickerModule]'s
 *                                    picker intent; always single-select, so
 *                                    `selectionLimit` has no effect on Android)
 *   - captureVideo(options)       -- video capture via ACTION_VIDEO_CAPTURE
 *   - scanQRCode()                -- not implemented on Android (see below)
 *   - stopQRScan()                -- no-op (nothing is ever started)
 *
 * Photo/video capture writes to a private `cacheDir/vuenative-camera` file and
 * hands the camera app write access to it via the FileProvider declared in
 * this module's AndroidManifest.xml (authority `${applicationId}.vuenative.fileprovider`).
 * The result payload mirrors iOS's `CameraModule.swift`: `{ uri, width, height,
 * type }` for photos, `{ uri, duration, type }` for video, and `{ didCancel:
 * true }` when the user backs out — never a mid-shape hybrid of the two.
 *
 * scanQRCode() is a real gap, not merely deferred: it needs either a live
 * camera preview + frame analysis (CameraX + ML Kit) or a raw Camera2 session,
 * neither of which this module pulls in as a dependency. It returns a clear,
 * actionable error rather than a silent no-op.
 */
class CameraModule : NativeModule {
    override val moduleName = "Camera"

    companion object {
        private const val REQUEST_CODE_LAUNCH_CAMERA = 9_301
        private const val REQUEST_CODE_LAUNCH_LIBRARY = 9_302
        private const val REQUEST_CODE_CAPTURE_VIDEO = 9_303
        private const val OUTPUT_DIR_NAME = "vuenative-camera"

        /** Weak reference to the current Activity, set by VueNativeActivity. */
        private var activityRef: WeakReference<Activity>? = null

        /** Callback for the in-flight capture, guarded by the companion lock. */
        private var pendingCallback: ((Any?, String?) -> Unit)? = null

        /** Destination file for the in-flight photo/video capture (null for the library pick). */
        private var pendingOutputFile: File? = null

        fun setActivity(activity: Activity?) {
            activityRef = if (activity != null) WeakReference(activity) else null
        }

        fun clearActivity(activity: Activity) {
            if (activityRef?.get() === activity) {
                activityRef = null
            }
            // A finishing host can never deliver a result; fail any pending
            // capture so the JS Promise settles instead of hanging until the
            // 30s timeout, and clean up its partially-written output file.
            failPending("Camera capture cancelled because the native host was destroyed")
        }

        /**
         * Called from `VueNativeActivity.onActivityResult` to resolve the pending
         * capture/pick. Routes by request code because the three flows (camera,
         * library, video) have distinct result shapes.
         */
        fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
            when (requestCode) {
                REQUEST_CODE_LAUNCH_CAMERA -> handleCaptureResult(resultCode) { file ->
                    val uri = Uri.fromFile(file)
                    val dimensions = activityRef?.get()?.contentResolver
                        ?.let { ImagePickerModule.readImageDimensions(it, uri) }
                    mapOf(
                        "uri" to uri.toString(),
                        "width" to (dimensions?.first ?: 0),
                        "height" to (dimensions?.second ?: 0),
                        "type" to "image/jpeg",
                    )
                }
                REQUEST_CODE_CAPTURE_VIDEO -> handleCaptureResult(resultCode) { file ->
                    mapOf(
                        "uri" to Uri.fromFile(file).toString(),
                        "duration" to readVideoDurationSeconds(file),
                        "type" to "video/mp4",
                    )
                }
                REQUEST_CODE_LAUNCH_LIBRARY -> handleLibraryResult(resultCode, data)
                else -> return
            }
        }

        /** Shared cancel/success plumbing for the file-based photo and video capture flows. */
        private fun handleCaptureResult(resultCode: Int, buildResult: (File) -> Map<String, Any?>) {
            val (callback, file) = takePending()
            if (callback == null) return
            if (resultCode != Activity.RESULT_OK || file == null || !file.exists() || file.length() <= 0L) {
                file?.delete()
                callback(mapOf("didCancel" to true), null)
                return
            }
            callback(buildResult(file), null)
        }

        private fun handleLibraryResult(resultCode: Int, data: Intent?) {
            val callback = takePending().first ?: return
            val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
            if (uri == null) {
                callback(mapOf("didCancel" to true), null)
                return
            }
            val resolver = activityRef?.get()?.contentResolver
            val dimensions = resolver?.let { ImagePickerModule.readImageDimensions(it, uri) }
            callback(
                mapOf(
                    "uri" to uri.toString(),
                    "width" to (dimensions?.first ?: 0),
                    "height" to (dimensions?.second ?: 0),
                    "type" to (resolver?.getType(uri) ?: "image/jpeg"),
                ),
                null,
            )
        }

        private fun readVideoDurationSeconds(file: File): Double {
            val retriever = MediaMetadataRetriever()
            return try {
                retriever.setDataSource(file.absolutePath)
                val millis = retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull() ?: 0L
                millis / 1000.0
            } catch (e: Exception) {
                0.0
            } finally {
                try {
                    retriever.release()
                } catch (e: Exception) {
                    // Nothing more to do — the retriever is being discarded either way.
                }
            }
        }

        /**
         * Register a new in-flight callback, atomically swapping out any previous
         * one (and its output file) so a superseding request never leaves the old
         * JS Promise hanging or leaks the old capture's temp file.
         */
        private fun registerPending(callback: (Any?, String?) -> Unit, outputFile: File?) {
            val (previousCallback, previousFile) = synchronized(this) {
                val previous = pendingCallback to pendingOutputFile
                pendingCallback = callback
                pendingOutputFile = outputFile
                previous
            }
            previousFile?.delete()
            previousCallback?.invoke(mapOf("didCancel" to true), null)
        }

        /** Clear the pending state only if [callback] is still current (i.e. launch failed before any result could arrive). */
        private fun clearPendingIfCurrent(callback: (Any?, String?) -> Unit) {
            synchronized(this) {
                if (pendingCallback === callback) {
                    pendingCallback = null
                    pendingOutputFile = null
                }
            }
        }

        /** Atomically take (and clear) both pending fields together so they never observe a mismatched pair. */
        private fun takePending(): Pair<((Any?, String?) -> Unit)?, File?> = synchronized(this) {
            val pending = pendingCallback to pendingOutputFile
            pendingCallback = null
            pendingOutputFile = null
            pending
        }

        private fun failPending(message: String) {
            val (callback, file) = takePending()
            file?.delete()
            callback?.invoke(null, message)
        }

        /** FileProvider authority for this host app, scoped per-applicationId (see AndroidManifest.xml). */
        internal fun fileProviderAuthority(context: Context): String =
            "${context.packageName}.vuenative.fileprovider"

        /** Create a fresh, uniquely named output file under `cacheDir/vuenative-camera`. */
        internal fun createOutputFile(context: Context, extension: String): File {
            val dir = File(context.cacheDir, OUTPUT_DIR_NAME).apply { mkdirs() }
            return File(dir, "vn_${UUID.randomUUID()}.$extension")
        }
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "launchCamera" -> launchCamera(callback)
            "launchImageLibrary" -> launchImageLibrary(callback)
            "captureVideo" -> captureVideo(args.getOrNull(0) as? Map<*, *>, callback)
            "scanQRCode" -> callback(
                null,
                "Camera.scanQRCode is not yet supported on Android — available on iOS. " +
                    "It requires a live camera preview + barcode analysis (e.g. CameraX + " +
                    "ML Kit), which this module does not currently depend on.",
            )
            "stopQRScan" -> callback(null, null)
            else -> callback(null, "Unknown Camera method: $method")
        }
    }

    // -- Photo capture -------------------------------------------------------------

    private fun launchCamera(callback: (Any?, String?) -> Unit) {
        val activity = activityRef?.get()
        if (activity == null) {
            callback(null, "Camera.launchCamera requires an active Activity host")
            return
        }
        val ctx = activity.applicationContext
        val file = try {
            createOutputFile(ctx, "jpg")
        } catch (e: Exception) {
            callback(null, "Failed to create output file for camera capture: ${e.message}")
            return
        }
        val uri = try {
            FileProvider.getUriForFile(ctx, fileProviderAuthority(ctx), file)
        } catch (e: Exception) {
            callback(null, "Failed to grant the camera app write access: ${e.message}")
            return
        }
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, uri)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
        registerPending(callback, file)
        try {
            // No camera app installed surfaces as ActivityNotFoundException here,
            // same as ImagePickerModule's picker launch — no separate
            // resolveActivity() precheck is needed.
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_CODE_LAUNCH_CAMERA)
        } catch (e: Exception) {
            clearPendingIfCurrent(callback)
            file.delete()
            callback(null, e.message ?: "Failed to launch camera")
        }
    }

    // -- Image library --------------------------------------------------------------

    private fun launchImageLibrary(callback: (Any?, String?) -> Unit) {
        val activity = activityRef?.get()
        if (activity == null) {
            callback(null, "Camera.launchImageLibrary requires an active Activity host")
            return
        }
        registerPending(callback, outputFile = null)
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(ImagePickerModule.buildPickIntent(), REQUEST_CODE_LAUNCH_LIBRARY)
        } catch (e: Exception) {
            clearPendingIfCurrent(callback)
            callback(null, e.message ?: "Failed to launch photo picker")
        }
    }

    // -- Video capture ----------------------------------------------------------------

    private fun captureVideo(options: Map<*, *>?, callback: (Any?, String?) -> Unit) {
        val activity = activityRef?.get()
        if (activity == null) {
            callback(null, "Camera.captureVideo requires an active Activity host")
            return
        }
        val ctx = activity.applicationContext
        val file = try {
            createOutputFile(ctx, "mp4")
        } catch (e: Exception) {
            callback(null, "Failed to create output file for video capture: ${e.message}")
            return
        }
        val uri = try {
            FileProvider.getUriForFile(ctx, fileProviderAuthority(ctx), file)
        } catch (e: Exception) {
            callback(null, "Failed to grant the camera app write access: ${e.message}")
            return
        }
        val intent = Intent(MediaStore.ACTION_VIDEO_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, uri)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            // The platform extra only distinguishes low (0) from high (1) — there
            // is no distinct "medium" bucket, so anything but "low" maps to high,
            // matching VideoCaptureOptions' "medium" default leaning toward quality.
            putExtra(MediaStore.EXTRA_VIDEO_QUALITY, if (options?.get("quality") == "low") 0 else 1)
            (options?.get("maxDuration") as? Number)?.let { seconds ->
                putExtra(MediaStore.EXTRA_DURATION_LIMIT, seconds.toInt())
            }
            if (options?.get("frontCamera") == true) {
                // Best-effort only: there is no public, guaranteed API to force the
                // front camera on an implicit ACTION_VIDEO_CAPTURE intent. Several
                // stock camera apps honor one of these undocumented extras; others
                // ignore both and simply open on the rear camera.
                putExtra("android.intent.extras.CAMERA_FACING", 1)
                putExtra("android.intent.extra.USE_FRONT_CAMERA", true)
            }
        }
        registerPending(callback, file)
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_CODE_CAPTURE_VIDEO)
        } catch (e: Exception) {
            clearPendingIfCurrent(callback)
            file.delete()
            callback(null, e.message ?: "Failed to launch video capture")
        }
    }
}
