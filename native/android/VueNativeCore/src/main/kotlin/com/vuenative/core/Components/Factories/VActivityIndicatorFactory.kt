package com.vuenative.core

import android.content.Context
import android.content.res.ColorStateList
import android.view.View
import android.view.ViewGroup
import android.widget.ProgressBar

class VActivityIndicatorFactory : NativeComponentFactory {
    override fun createView(context: Context): View {
        return ProgressBar(context).apply {
            isIndeterminate = true
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val pb = view as? ProgressBar ?: return
        when (key) {
            "animating" -> pb.visibility = if (value == true || value == "true") View.VISIBLE else View.GONE
            "size" -> {
                val sizePx = when (value) {
                    "small" -> (20 * view.context.resources.displayMetrics.density).toInt()
                    "large" -> (48 * view.context.resources.displayMetrics.density).toInt()
                    else    -> (32 * view.context.resources.displayMetrics.density).toInt()
                }
                pb.layoutParams?.also { lp ->
                    lp.width = sizePx
                    lp.height = sizePx
                    pb.layoutParams = lp
                }
            }
            "color" -> {
                val color = StyleEngine.parseColor(value) ?: return
                pb.indeterminateTintList = ColorStateList.valueOf(color)
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {}
    override fun removeEventListener(view: View, event: String) {}
}
