package com.vuenative.core

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.lang.ref.WeakReference

class PermissionsModule : NativeModule {
    override val moduleName = "Permissions"
    private var context: Context? = null
    private var prefs: SharedPreferences? = null

    companion object {
        private const val PREFS_NAME = "vue_native_permissions"
        private const val REQUEST_CODE_BASE = 9100

        /** Weak reference to the current Activity, set by VueNativeActivity. */
        private var activityRef: WeakReference<Activity>? = null

        /** Pending callbacks keyed by request code. */
        internal val pendingCallbacks = mutableMapOf<Int, (Any?, String?) -> Unit>()

        /** Request code counter. */
        private var nextRequestCode = REQUEST_CODE_BASE

        fun setActivity(activity: Activity?) {
            activityRef = if (activity != null) WeakReference(activity) else null
        }

        /**
         * Called from VueNativeActivity.onRequestPermissionsResult to resolve pending callbacks.
         */
        fun onPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
            val callback = pendingCallbacks.remove(requestCode) ?: return
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                callback("granted", null)
            } else {
                callback("denied", null)
            }
        }
    }

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
        this.prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val ctx = context ?: run {
            callback(null, "Not initialized")
            return
        }
        when (method) {
            "check" -> {
                val permission = args.getOrNull(0)?.toString() ?: run {
                    callback("denied", null)
                    return
                }
                val androidPerm = mapPermission(permission)
                if (androidPerm == null) {
                    callback("denied", null)
                    return
                }
                callback(checkStatus(ctx, androidPerm), null)
            }
            "request" -> {
                val permission = args.getOrNull(0)?.toString() ?: run {
                    callback("denied", null)
                    return
                }
                val androidPerm = mapPermission(permission)
                if (androidPerm == null) {
                    callback("denied", null)
                    return
                }

                // If already granted, return immediately
                if (ContextCompat.checkSelfPermission(ctx, androidPerm) == PackageManager.PERMISSION_GRANTED) {
                    callback("granted", null)
                    return
                }

                // Try to request via Activity
                val activity = activityRef?.get()
                if (activity == null) {
                    // No Activity reference — fall back to returning current status
                    callback(checkStatus(ctx, androidPerm), null)
                    return
                }

                // Mark this permission as having been requested
                prefs?.edit()?.putBoolean(androidPerm, true)?.apply()

                val requestCode = nextRequestCode++
                pendingCallbacks[requestCode] = callback
                ActivityCompat.requestPermissions(activity, arrayOf(androidPerm), requestCode)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }

    /**
     * Determine permission status with notDetermined support.
     * - granted: permission is granted
     * - notDetermined: permission denied AND rationale not needed AND never requested before
     * - denied: permission denied (user has previously denied or "don't ask again")
     */
    private fun checkStatus(ctx: Context, androidPerm: String): String {
        if (ContextCompat.checkSelfPermission(ctx, androidPerm) == PackageManager.PERMISSION_GRANTED) {
            return "granted"
        }
        // Check if we've ever requested this permission
        val wasRequested = prefs?.getBoolean(androidPerm, false) ?: false
        if (!wasRequested) {
            // Never requested — this is "notDetermined"
            return "notDetermined"
        }
        // Already requested and denied
        return "denied"
    }

    private fun mapPermission(name: String): String? = when (name) {
        "camera" -> Manifest.permission.CAMERA
        "microphone" -> Manifest.permission.RECORD_AUDIO
        "photos" -> if (android.os.Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES else Manifest.permission.READ_EXTERNAL_STORAGE
        "location" -> Manifest.permission.ACCESS_FINE_LOCATION
        "locationAlways" -> Manifest.permission.ACCESS_BACKGROUND_LOCATION
        "notifications" -> if (android.os.Build.VERSION.SDK_INT >= 33) Manifest.permission.POST_NOTIFICATIONS else null
        else -> null
    }
}
