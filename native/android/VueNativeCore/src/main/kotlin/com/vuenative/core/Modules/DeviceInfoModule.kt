package com.vuenative.core

import android.content.Context
import android.content.res.Configuration
import android.os.Build

class DeviceInfoModule : NativeModule {
    override val moduleName = "DeviceInfo"
    private var context: Context? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val ctx = context ?: run { callback(null, "Not initialized"); return }
        when (method) {
            "getDeviceInfo", "getInfo" -> {
                val dm = ctx.resources.displayMetrics
                callback(mapOf(
                    "model"         to "${Build.MANUFACTURER} ${Build.MODEL}",
                    "brand"         to Build.MANUFACTURER,
                    "deviceName"    to Build.MODEL,
                    "systemName"    to "Android",
                    "systemVersion" to Build.VERSION.RELEASE,
                    "screenWidth"   to (dm.widthPixels / dm.density).toDouble(),
                    "screenHeight"  to (dm.heightPixels / dm.density).toDouble(),
                    "screenScale"   to dm.density.toDouble(),
                    "isTablet"      to (ctx.resources.configuration.screenLayout and
                                       Configuration.SCREENLAYOUT_SIZE_MASK >=
                                       Configuration.SCREENLAYOUT_SIZE_LARGE),
                    "platform"      to "android",
                    "bundleId"      to ctx.packageName,
                ), null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }
}
