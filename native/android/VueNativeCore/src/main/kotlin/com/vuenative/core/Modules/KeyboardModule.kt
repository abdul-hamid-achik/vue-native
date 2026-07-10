package com.vuenative.core

import android.app.Activity
import android.content.Context
import android.graphics.Rect
import android.os.Build
import android.view.WindowInsets
import android.view.inputmethod.InputMethodManager

class KeyboardModule : NativeModule {
    override val moduleName = "Keyboard"
    private var context: Context? = null
    private var activity: Activity? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
        this.activity = context as? Activity
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val ctx = context ?: run {
            callback(null, "Not initialized")
            return
        }
        when (method) {
            "dismiss" -> {
                val imm = ctx.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                val host = activity
                val token = host?.currentFocus?.windowToken ?: host?.window?.decorView?.windowToken
                if (token != null) imm.hideSoftInputFromWindow(token, 0)
                callback(null, null)
            }
            "getHeight", "getKeyboardHeight" -> callback(keyboardMetrics(), null)
            else -> callback(null, "Unknown method: $method")
        }
    }

    private fun keyboardMetrics(): Map<String, Any> {
        val decorView = activity?.window?.decorView
            ?: return mapOf("height" to 0, "isVisible" to false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val insets = decorView.rootWindowInsets
            val visible = insets?.isVisible(WindowInsets.Type.ime()) == true
            val height = if (visible) insets?.getInsets(WindowInsets.Type.ime())?.bottom ?: 0 else 0
            return mapOf("height" to height, "isVisible" to visible)
        }

        @Suppress("DEPRECATION")
        val frame = Rect().also(decorView::getWindowVisibleDisplayFrame)
        val obscuredHeight = (decorView.rootView.height - frame.bottom).coerceAtLeast(0)
        val threshold = (decorView.resources.displayMetrics.density * 100).toInt()
        val visible = obscuredHeight > threshold
        return mapOf("height" to if (visible) obscuredHeight else 0, "isVisible" to visible)
    }

    override fun destroy() {
        activity = null
        context = null
    }
}
