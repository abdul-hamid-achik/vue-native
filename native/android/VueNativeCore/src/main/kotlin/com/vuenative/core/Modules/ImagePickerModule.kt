package com.vuenative.core

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import java.lang.ref.WeakReference

/**
 * ImagePicker module — backs the runtime `useImagePicker` composable
 * (`packages/runtime/src/composables/useImagePicker.ts`).
 *
 * `pickImage` presents the system photo picker and resolves to
 * `{ uri, width, height }`, or `null` when the user cancels.
 *
 * The picker requires an Activity host to launch `startActivityForResult` and a
 * host-routed `onActivityResult` to observe the result, mirroring the static
 * Activity pattern used by [PermissionsModule]. [VueNativeActivity] installs the
 * Activity reference in `onCreate`, clears it in `onDestroy`, and forwards
 * `onActivityResult` to [onActivityResult].
 *
 * Picker selection:
 *  - API 33+ (Tiramisu): the dedicated Photo Picker (`MediaStore.ACTION_PICK_IMAGES`),
 *    which needs no storage permission.
 *  - Below API 33: `ACTION_GET_CONTENT` filtering on image MIME types (the
 *    Storage Access Framework picker), also permission-free.
 */
class ImagePickerModule : NativeModule {
    override val moduleName = "ImagePicker"

    companion object {
        /** Fixed request code — only one pick may be in flight at a time. */
        internal const val REQUEST_CODE = 9200

        /** Weak reference to the current Activity, set by VueNativeActivity. */
        private var activityRef: WeakReference<Activity>? = null

        /** Callback for the in-flight pick, guarded by the companion lock. */
        private var pendingCallback: ((Any?, String?) -> Unit)? = null

        fun setActivity(activity: Activity?) {
            activityRef = if (activity != null) WeakReference(activity) else null
        }

        fun clearActivity(activity: Activity) {
            if (activityRef?.get() === activity) {
                activityRef = null
            }
            // A finishing host can never deliver a result; fail any pending pick
            // so the JS Promise settles instead of hanging until the 30s timeout.
            val callback = synchronized(this) {
                pendingCallback?.also { pendingCallback = null }
            }
            callback?.invoke(null, "ImagePicker cancelled because the native host was destroyed")
        }

        /**
         * Called from `VueNativeActivity.onActivityResult` to resolve the pending
         * pick. A `RESULT_OK` result with a data URI resolves to the picked image
         * metadata; anything else (cancel, no data) resolves to `null`.
         */
        fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
            if (requestCode != REQUEST_CODE) return

            val callback = synchronized(this) {
                pendingCallback?.also { pendingCallback = null }
            } ?: return

            val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
            if (uri == null) {
                // User cancelled (or the picker returned no selection).
                callback(null, null)
                return
            }

            val dimensions = activityRef?.get()
                ?.contentResolver
                ?.let { readImageDimensions(it, uri) }

            callback(
                mapOf(
                    "uri" to uri.toString(),
                    "width" to (dimensions?.first ?: 0),
                    "height" to (dimensions?.second ?: 0),
                ),
                null,
            )
        }

        /** Build the system picker intent for the current API level. */
        internal fun buildPickIntent(): Intent =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                Intent(MediaStore.ACTION_PICK_IMAGES)
            } else {
                Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "image/*"
                    addCategory(Intent.CATEGORY_OPENABLE)
                }
            }

        /**
         * Decode an image's pixel dimensions without allocating the bitmap, using
         * `inJustDecodeBounds`. Returns `null` when the stream cannot be decoded.
         */
        internal fun readImageDimensions(resolver: ContentResolver, uri: Uri): Pair<Int, Int>? =
            try {
                resolver.openInputStream(uri)?.use { input ->
                    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeStream(input, null, options)
                    if (options.outWidth > 0 && options.outHeight > 0) {
                        options.outWidth to options.outHeight
                    } else {
                        null
                    }
                }
            } catch (e: Exception) {
                null
            }
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "pickImage" -> pickImage(callback)
            else -> callback(null, "Unknown method: $method")
        }
    }

    private fun pickImage(callback: (Any?, String?) -> Unit) {
        val activity = activityRef?.get()
        if (activity == null) {
            callback(null, "ImagePicker requires an active Activity host")
            return
        }

        synchronized(Companion) {
            // A new pick supersedes any in-flight one; settle the old Promise as
            // cancelled so it does not hang.
            pendingCallback?.invoke(null, null)
            pendingCallback = callback
        }

        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(buildPickIntent(), REQUEST_CODE)
        } catch (e: Exception) {
            synchronized(Companion) {
                if (pendingCallback === callback) pendingCallback = null
            }
            callback(null, e.message ?: "Failed to launch photo picker")
        }
    }
}
