package com.vuenative.core

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context

class ClipboardModule : NativeModule {
    override val moduleName = "Clipboard"
    private var clipboard: ClipboardManager? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val cb = clipboard ?: run {
            callback(null, "Clipboard not available")
            return
        }
        when (method) {
            "setString", "setContent" -> {
                val text = args.getOrNull(0)?.toString() ?: ""
                cb.setPrimaryClip(ClipData.newPlainText("VueNative", text))
                callback(null, null)
            }
            "getString", "getContent" -> {
                val clip = cb.primaryClip
                val text = if (clip != null && clip.itemCount > 0) {
                    clip.getItemAt(0)?.text?.toString()
                } else {
                    null
                }
                callback(text, null)
            }
            "hasString" -> {
                callback(cb.hasPrimaryClip(), null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }
}
