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

        /** Owner tokens let sibling modules cancel only the requests they initiated. */
        private val pendingOwners = mutableMapOf<Int, Any>()

        /** Request code counter. */
        private var nextRequestCode = REQUEST_CODE_BASE

        fun setActivity(activity: Activity?) {
            activityRef = if (activity != null) WeakReference(activity) else null
        }

        fun clearActivity(activity: Activity) {
            if (activityRef?.get() === activity) activityRef = null
        }

        /**
         * Called from VueNativeActivity.onRequestPermissionsResult to resolve pending callbacks.
         */
        @Suppress("UNUSED_PARAMETER")
        fun onPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
            val callback = synchronized(this) {
                pendingOwners.remove(requestCode)
                pendingCallbacks.remove(requestCode)
            } ?: return
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                callback("granted", null)
            } else {
                callback("denied", null)
            }
        }

        private fun addPendingRequest(
            owner: Any,
            callback: (Any?, String?) -> Unit,
        ): Int = synchronized(this) {
            val requestCode = nextRequestCode++
            pendingCallbacks[requestCode] = callback
            pendingOwners[requestCode] = owner
            requestCode
        }

        private fun removePendingRequests(owner: Any): List<(Any?, String?) -> Unit> =
            synchronized(this) {
                val requestCodes = pendingOwners
                    .filterValues { it === owner }
                    .keys
                    .toList()
                requestCodes.mapNotNull { requestCode ->
                    pendingOwners.remove(requestCode)
                    pendingCallbacks.remove(requestCode)
                }
            }

        private fun removeAllPendingRequests(): List<(Any?, String?) -> Unit> =
            synchronized(this) {
                val callbacks = pendingCallbacks.values.toList()
                pendingCallbacks.clear()
                pendingOwners.clear()
                callbacks
            }
    }

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
        this.prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        when (method) {
            "check" -> {
                checkNamedPermission(args.getOrNull(0)?.toString(), callback)
            }
            "request" -> {
                requestNamedPermission(args.getOrNull(0)?.toString(), this, callback)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }

    /** Check a public Vue Native permission name without displaying a prompt. */
    internal fun checkNamedPermission(
        permission: String?,
        callback: (Any?, String?) -> Unit,
    ) {
        val ctx = context ?: run {
            callback(null, "Not initialized")
            return
        }
        if (isImplicitlyGranted(permission)) {
            callback("granted", null)
            return
        }
        val androidPerm = permission?.let(::mapPermission) ?: run {
            callback("denied", null)
            return
        }
        callback(checkStatus(ctx, androidPerm), null)
    }

    /**
     * Request a public Vue Native permission name on behalf of [owner].
     *
     * Notification permission uses this path too, so every runtime permission is
     * routed through the Activity's single `onRequestPermissionsResult` handler.
     */
    internal fun requestNamedPermission(
        permission: String?,
        owner: Any,
        callback: (Any?, String?) -> Unit,
    ) {
        val ctx = context ?: run {
            callback(null, "Not initialized")
            return
        }
        if (isImplicitlyGranted(permission)) {
            callback("granted", null)
            return
        }
        val androidPerm = permission?.let(::mapPermission) ?: run {
            callback("denied", null)
            return
        }

        if (ContextCompat.checkSelfPermission(ctx, androidPerm) == PackageManager.PERMISSION_GRANTED) {
            callback("granted", null)
            return
        }

        val activity = activityRef?.get()
        if (activity == null) {
            // A request cannot display a system prompt without an active host.
            callback(checkStatus(ctx, androidPerm), null)
            return
        }

        prefs?.edit()?.putBoolean(androidPerm, true)?.apply()
        val requestCode = addPendingRequest(owner, callback)
        ActivityCompat.requestPermissions(activity, arrayOf(androidPerm), requestCode)
    }

    /** Reject outstanding requests owned by a module that is being destroyed. */
    internal fun cancelPendingRequests(owner: Any, message: String) {
        removePendingRequests(owner).forEach { callback -> callback(null, message) }
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

    private fun isImplicitlyGranted(permission: String?): Boolean =
        permission == "notifications" &&
            android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.TIRAMISU

    private fun mapPermission(name: String): String? = when (name) {
        "camera" -> Manifest.permission.CAMERA
        "microphone" -> Manifest.permission.RECORD_AUDIO
        "photos" -> if (android.os.Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES else Manifest.permission.READ_EXTERNAL_STORAGE
        "location" -> Manifest.permission.ACCESS_FINE_LOCATION
        "locationAlways" -> Manifest.permission.ACCESS_BACKGROUND_LOCATION
        "notifications" -> if (android.os.Build.VERSION.SDK_INT >= 33) Manifest.permission.POST_NOTIFICATIONS else null
        else -> null
    }

    override fun destroy() {
        context = null
        prefs = null
        removeAllPendingRequests().forEach { callback ->
            callback(null, "Permission request cancelled because the native host was destroyed")
        }
    }
}
