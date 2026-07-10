package com.vuenative.core

import android.content.Context
import android.content.res.Configuration
import android.os.Build
import java.util.Locale

class DeviceInfoModule : NativeModule {
    companion object {
        /** Shared DeviceInfo schema used by initial queries and configuration events. */
        fun snapshot(context: Context): Map<String, Any> {
            val metrics = context.resources.displayMetrics
            val configuration = context.resources.configuration
            val scale = metrics.density.toDouble()
            val name = Build.MODEL
            return mapOf(
                "model" to "${Build.MANUFACTURER} $name",
                "brand" to Build.MANUFACTURER,
                "name" to name,
                // Keep historical Android keys while the public runtime schema
                // converges on name/scale.
                "deviceName" to name,
                "systemName" to "Android",
                "systemVersion" to Build.VERSION.RELEASE,
                "screenWidth" to (metrics.widthPixels / metrics.density).toDouble(),
                "screenHeight" to (metrics.heightPixels / metrics.density).toDouble(),
                "scale" to scale,
                "screenScale" to scale,
                "locale" to locale(configuration),
                "colorScheme" to colorScheme(configuration),
                "isTablet" to (configuration.screenLayout and
                    Configuration.SCREENLAYOUT_SIZE_MASK >= Configuration.SCREENLAYOUT_SIZE_LARGE),
                "platform" to "android",
                "bundleId" to context.packageName,
            )
        }

        fun dimensions(context: Context): Map<String, Any> {
            val metrics = context.resources.displayMetrics
            return mapOf(
                "width" to (metrics.widthPixels / metrics.density).toDouble(),
                "height" to (metrics.heightPixels / metrics.density).toDouble(),
                "scale" to metrics.density.toDouble(),
            )
        }

        fun colorScheme(configuration: Configuration): String =
            if (configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
                Configuration.UI_MODE_NIGHT_YES
            ) {
                "dark"
            } else {
                "light"
            }

        @Suppress("DEPRECATION")
        private fun locale(configuration: Configuration): String {
            val locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                configuration.locales.get(0)
            } else {
                configuration.locale
            } ?: Locale.getDefault()
            return locale.toLanguageTag().ifBlank { Locale.getDefault().toLanguageTag() }
        }
    }

    override val moduleName = "DeviceInfo"
    private var context: Context? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val ctx = context ?: run {
            callback(null, "Not initialized")
            return
        }
        when (method) {
            "getDeviceInfo", "getInfo" -> callback(snapshot(ctx), null)
            else -> callback(null, "Unknown method: $method")
        }
    }
}
