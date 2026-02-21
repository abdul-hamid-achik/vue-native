package com.vuenative.core

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat

class PermissionsModule : NativeModule {
    override val moduleName = "Permissions"
    private var context: Context? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val ctx = context ?: run { callback(null, "Not initialized"); return }
        when (method) {
            "check" -> {
                val permission = args.getOrNull(0)?.toString() ?: run { callback("denied", null); return }
                val androidPerm = mapPermission(permission)
                val status = if (androidPerm != null) {
                    if (ContextCompat.checkSelfPermission(ctx, androidPerm) == PackageManager.PERMISSION_GRANTED)
                        "granted" else "denied"
                } else "denied"
                callback(status, null)
            }
            "request" -> {
                // Permission request requires an Activity -- return current status
                val permission = args.getOrNull(0)?.toString() ?: run { callback("denied", null); return }
                val androidPerm = mapPermission(permission)
                val status = if (androidPerm != null) {
                    if (ContextCompat.checkSelfPermission(ctx, androidPerm) == PackageManager.PERMISSION_GRANTED)
                        "granted" else "denied"
                } else "denied"
                callback(status, null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }

    private fun mapPermission(name: String): String? = when (name) {
        "camera"        -> Manifest.permission.CAMERA
        "microphone"    -> Manifest.permission.RECORD_AUDIO
        "photos"        -> if (android.os.Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES else Manifest.permission.READ_EXTERNAL_STORAGE
        "location"      -> Manifest.permission.ACCESS_FINE_LOCATION
        "notifications" -> if (android.os.Build.VERSION.SDK_INT >= 33) Manifest.permission.POST_NOTIFICATIONS else null
        else -> null
    }
}
