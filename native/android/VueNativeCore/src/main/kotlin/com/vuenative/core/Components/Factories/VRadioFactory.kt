package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.RadioButton
import android.widget.RadioGroup
import org.json.JSONArray

class VRadioFactory : NativeComponentFactory {
    private val changeHandlers = mutableMapOf<RadioGroup, (Any?) -> Unit>()
    private val optionValues = mutableMapOf<RadioGroup, List<String>>()

    override fun createView(context: Context): View {
        return RadioGroup(context).apply {
            orientation = RadioGroup.VERTICAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val rg = view as? RadioGroup ?: return
        when (key) {
            "options" -> {
                val items = when (value) {
                    is JSONArray -> (0 until value.length()).map { i ->
                        val obj = value.getJSONObject(i)
                        Pair(obj.optString("label", ""), obj.optString("value", ""))
                    }
                    is List<*> -> value.filterIsInstance<Map<*, *>>().map { m ->
                        Pair(m["label"]?.toString() ?: "", m["value"]?.toString() ?: "")
                    }
                    else -> emptyList()
                }
                optionValues[rg] = items.map { it.second }
                rg.removeAllViews()
                items.forEachIndexed { i, (label, _) ->
                    val btn = RadioButton(rg.context).apply {
                        text = label
                        id = View.generateViewId()
                        setPadding(0, 16, 24, 16)
                    }
                    rg.addView(btn)
                }
                // Re-apply selection
                applySelection(rg)
            }
            "selectedValue" -> {
                rg.tag = value?.toString()
                applySelection(rg)
            }
            "disabled" -> {
                val disabled = value == true || value == "true"
                rg.isEnabled = !disabled
                rg.alpha = if (disabled) 0.4f else 1.0f
                (0 until rg.childCount).forEach {
                    rg.getChildAt(it).isEnabled = !disabled
                }
            }
            "tintColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                (0 until rg.childCount).forEach { i ->
                    (rg.getChildAt(i) as? RadioButton)?.buttonTintList =
                        android.content.res.ColorStateList.valueOf(color)
                }
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val rg = view as? RadioGroup ?: return
        if (event == "change") {
            changeHandlers[rg] = handler
            rg.setOnCheckedChangeListener { group, checkedId ->
                val idx = (0 until group.childCount).indexOfFirst { group.getChildAt(it).id == checkedId }
                val value = optionValues[group]?.getOrNull(idx) ?: ""
                changeHandlers[group]?.invoke(mapOf("value" to value))
            }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val rg = view as? RadioGroup ?: return
        if (event == "change") {
            changeHandlers.remove(rg)
            rg.setOnCheckedChangeListener(null)
        }
    }

    private fun applySelection(rg: RadioGroup) {
        val selected = rg.tag as? String ?: return
        val values = optionValues[rg] ?: return
        val idx = values.indexOf(selected)
        if (idx >= 0 && idx < rg.childCount) {
            val child = rg.getChildAt(idx) as? RadioButton
            child?.id?.let { rg.check(it) }
        }
    }
}
