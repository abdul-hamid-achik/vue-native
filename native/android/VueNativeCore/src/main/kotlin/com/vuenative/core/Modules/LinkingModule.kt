package com.vuenative.core

import android.content.Context
import android.content.Intent
import android.net.Uri

class LinkingModule : NativeModule {
    override val moduleName = "Linking"
    private var context: Context? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val ctx = context ?: run { callback(null, "Not initialized"); return }
        when (method) {
            "openURL" -> {
                val url = args.getOrNull(0)?.toString() ?: run { callback(null, "Missing URL"); return }
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
                val url = args.getOrNull(0)?.toString() ?: run { callback(false, null); return }
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                val canOpen = ctx.packageManager.resolveActivity(intent, 0) != null
                callback(canOpen, null)
            }
            "getInitialURL" -> callback(null, null)
            else -> callback(null, "Unknown method: $method")
        }
    }
}
