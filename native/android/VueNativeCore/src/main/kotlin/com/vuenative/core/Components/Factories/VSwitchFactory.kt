package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.Switch
import androidx.appcompat.widget.SwitchCompat

class VSwitchFactory : NativeComponentFactory {
    private val changeHandlers = mutableMapOf<SwitchCompat, (Any?) -> Unit>()

    override fun createView(context: Context): View {
        return SwitchCompat(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val sw = view as? SwitchCompat ?: return
        when (key) {
            "value" -> {
                val b = value == true || value == "true" || value == 1
                if (sw.isChecked != b) sw.isChecked = b
            }
            "disabled" -> sw.isEnabled = value != true && value != "true"
            "onTintColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                sw.thumbTintList = android.content.res.ColorStateList.valueOf(color)
            }
            "thumbColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                sw.thumbTintList = android.content.res.ColorStateList.valueOf(color)
            }
            "trackColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                sw.trackTintList = android.content.res.ColorStateList.valueOf(color)
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val sw = view as? SwitchCompat ?: return
        if (event == "change" || event == "valueChange") {
            changeHandlers[sw] = handler
            sw.setOnCheckedChangeListener { _, isChecked ->
                changeHandlers[sw]?.invoke(mapOf("value" to isChecked))
            }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val sw = view as? SwitchCompat ?: return
        if (event == "change" || event == "valueChange") {
            changeHandlers.remove(sw)
            sw.setOnCheckedChangeListener(null)
        }
    }
}
