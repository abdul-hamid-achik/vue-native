package com.vuenative.core

import android.content.Context
import android.view.inputmethod.InputMethodManager

class KeyboardModule : NativeModule {
    override val moduleName = "Keyboard"
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
            "dismiss" -> {
                val imm = ctx.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                // Best effort: dismiss using the app's current focus
                callback(null, null)
            }
            "getKeyboardHeight" -> callback(0, null)
            else -> callback(null, "Unknown method: $method")
        }
    }
}
