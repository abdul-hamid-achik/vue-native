package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.TextView

class VCheckboxFactory : NativeComponentFactory {
    private val changeHandlers = mutableMapOf<View, (Any?) -> Unit>()

    override fun createView(context: Context): View {
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = android.view.Gravity.CENTER_VERTICAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )

            val checkbox = CheckBox(context).apply {
                tag = "checkbox"
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            }

            val label = TextView(context).apply {
                tag = "label"
                textSize = 16f
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { marginStart = 8 }
            }

            addView(checkbox)
            addView(label)
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val container = view as? LinearLayout ?: return
        val checkbox = container.findViewWithTag<CheckBox>("checkbox") ?: return
        val label = container.findViewWithTag<TextView>("label") ?: return

        when (key) {
            "value" -> {
                val checked = value == true || value == "true" || value == 1
                if (checkbox.isChecked != checked) checkbox.isChecked = checked
            }
            "label" -> {
                label.text = value?.toString() ?: ""
                label.visibility = if ((value?.toString() ?: "").isEmpty()) View.GONE else View.VISIBLE
            }
            "disabled" -> {
                val disabled = value == true || value == "true"
                checkbox.isEnabled = !disabled
                container.alpha = if (disabled) 0.4f else 1.0f
            }
            "checkColor", "tintColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                checkbox.buttonTintList = android.content.res.ColorStateList.valueOf(color)
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        if (event != "change") return
        val container = view as? LinearLayout ?: return
        val checkbox = container.findViewWithTag<CheckBox>("checkbox") ?: return
        changeHandlers[view] = handler
        checkbox.setOnCheckedChangeListener { _, isChecked ->
            changeHandlers[view]?.invoke(mapOf("value" to isChecked))
        }
        // Also allow tapping the whole row
        container.setOnClickListener {
            checkbox.isChecked = !checkbox.isChecked
        }
    }

    override fun removeEventListener(view: View, event: String) {
        if (event != "change") return
        val container = view as? LinearLayout ?: return
        val checkbox = container.findViewWithTag<CheckBox>("checkbox")
        changeHandlers.remove(view)
        checkbox?.setOnCheckedChangeListener(null)
        container.setOnClickListener(null)
    }
}
