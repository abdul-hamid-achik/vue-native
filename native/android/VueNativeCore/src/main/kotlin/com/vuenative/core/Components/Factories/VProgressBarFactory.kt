package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.ProgressBar

class VProgressBarFactory : NativeComponentFactory {
    override fun createView(context: Context): View {
        return ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal).apply {
            isIndeterminate = false
            max = 1000
            progress = 0
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val pb = view as? ProgressBar ?: return
        when (key) {
            "progress" -> {
                val f = StyleEngine.toFloat(value, 0f).coerceIn(0f, 1f)
                pb.progress = (f * pb.max).toInt()
            }
            "progressTintColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                pb.progressTintList = android.content.res.ColorStateList.valueOf(color)
            }
            "trackTintColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                pb.progressBackgroundTintList = android.content.res.ColorStateList.valueOf(color)
            }
            "animated" -> {} // Android ProgressBar animates by default
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {}
    override fun removeEventListener(view: View, event: String) {}
}
