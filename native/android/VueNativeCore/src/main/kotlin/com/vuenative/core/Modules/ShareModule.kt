package com.vuenative.core

import android.content.Context
import android.content.Intent

class ShareModule : NativeModule {
    override val moduleName = "Share"
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
            "share" -> {
                val content = args.getOrNull(0) as? Map<*, *>
                val message = content?.get("message")?.toString() ?: ""
                val url = content?.get("url")?.toString() ?: ""
                val text = if (url.isNotEmpty()) "$message\n$url" else message

                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                ctx.startActivity(Intent.createChooser(intent, "Share via").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                })
                callback(mapOf("shared" to true), null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }
}
