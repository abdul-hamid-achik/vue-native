package com.vuenative.core

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import java.util.concurrent.CopyOnWriteArraySet

class LinkingModule : NativeModule {
    override val moduleName = "Linking"
    private var context: Context? = null

    /** The URL that launched the app. Set by VueNativeActivity from the launch intent. */
    var initialURL: String? = null

    companion object {
        private const val TAG = "VueNative-Linking"

        /**
         * Escape hatch for [canOpenURL] under Android 11+ package-visibility
         * rules.
         *
         * Since API 30, `PackageManager.queryIntentActivities()` /
         * `resolveActivity()` only see packages the app declared in a
         * `<queries>` block, so `canOpenURL("myapp://…")` returned `false` for
         * every custom deep-link scheme a host had not listed. The library
         * manifest declares `<queries>` for `http`, `https`, `mailto` and `tel`;
         * hosts should add their own `<intent>` blocks for anything else.
         *
         * When that is not practical (a scheme resolved dynamically, a
         * third-party SDK, …) register it here from your `Application` class and
         * `canOpenURL` answers `true` without consulting the PackageManager:
         *
         * ```kotlin
         * class MyApp : Application() {
         *     override fun onCreate() {
         *         super.onCreate()
         *         LinkingModule.registerOpenableSchemes("myapp", "whatsapp")
         *     }
         * }
         * ```
         *
         * This is an explicit opt-in: it makes `canOpenURL` optimistic for the
         * listed schemes, so only register ones you know the device can handle.
         */
        private val openableSchemes = CopyOnWriteArraySet<String>()

        /** Register URL schemes [canOpenURL] should treat as openable without a query. */
        fun registerOpenableSchemes(vararg schemes: String) {
            schemes.forEach { raw ->
                val scheme = raw.trim().removeSuffix("://").removeSuffix(":").lowercase()
                if (scheme.isNotEmpty()) openableSchemes.add(scheme)
            }
        }

        /** Drop every scheme registered through [registerOpenableSchemes]. */
        fun clearOpenableSchemes() {
            openableSchemes.clear()
        }

        internal fun isRegisteredScheme(scheme: String?): Boolean =
            scheme != null && scheme.lowercase() in openableSchemes
    }

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val ctx = context ?: run {
            callback(null, "Not initialized")
            return
        }
        when (method) {
            "openURL" -> {
                val url = args.getOrNull(0)?.toString() ?: run {
                    callback(null, "Missing URL")
                    return
                }
                try {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    ctx.startActivity(intent)
                    callback(null, null)
                } catch (e: Exception) {
                    callback(null, e.message)
                }
            }
            "canOpenURL" -> {
                val url = args.getOrNull(0)?.toString() ?: run {
                    callback(false, null)
                    return
                }
                callback(canOpen(ctx, url), null)
            }
            "getInitialURL" -> callback(initialURL, null)
            else -> callback(null, "Unknown method: $method")
        }
    }

    /** Visible for tests. */
    internal fun canOpen(ctx: Context, url: String): Boolean {
        val uri = try {
            Uri.parse(url)
        } catch (e: Exception) {
            Log.w(TAG, "canOpenURL: could not parse '$url': ${e.message}")
            return false
        }
        if (isRegisteredScheme(uri.scheme)) return true

        val intent = Intent(Intent.ACTION_VIEW, uri)
        return try {
            // queryIntentActivities, not resolveActivity: resolveActivity needs a
            // single "best" match and returns null in strictly more cases (e.g.
            // when no handler declares the DEFAULT category), which made
            // canOpenURL report false for URLs the device could open.
            ctx.packageManager.queryIntentActivities(intent, 0).isNotEmpty()
        } catch (e: Throwable) {
            // PackageManager calls into the system server; a TransactionTooLarge
            // or DeadObject error must not take the caller down with it.
            Log.w(TAG, "canOpenURL query failed for '$url': ${e.message}")
            false
        }
    }
}
