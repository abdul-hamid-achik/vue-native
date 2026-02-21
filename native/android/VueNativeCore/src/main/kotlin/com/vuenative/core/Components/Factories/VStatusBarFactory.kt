package com.vuenative.core

import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsetsController
import android.content.Context

class VStatusBarFactory : NativeComponentFactory {
    override fun createView(context: Context): View = View(context).apply {
        layoutParams = ViewGroup.LayoutParams(0, 0)
        visibility = View.GONE
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val activity = view.context as? androidx.appcompat.app.AppCompatActivity ?: return
        val window = activity.window
        when (key) {
            "barStyle" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val controller = window.insetsController
                    when (value) {
                        "light-content" -> controller?.setSystemBarsAppearance(0, WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS)
                        "dark-content"  -> controller?.setSystemBarsAppearance(WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS, WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS)
                    }
                } else {
                    @Suppress("DEPRECATION")
                    val flags = window.decorView.systemUiVisibility
                    window.decorView.systemUiVisibility = when (value) {
                        "dark-content"  -> flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                        "light-content" -> flags and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
                        else -> flags
                    }
                }
            }
            "hidden" -> {
                if (value == true || value == "true") {
                    window.addFlags(android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN)
                } else {
                    window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN)
                }
            }
            "backgroundColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                window.statusBarColor = color
            }
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {}
    override fun removeEventListener(view: View, event: String) {}
}
