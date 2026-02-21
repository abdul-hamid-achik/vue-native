package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.RadioButton
import android.widget.RadioGroup
import org.json.JSONArray

class VSegmentedControlFactory : NativeComponentFactory {
    private val changeHandlers = mutableMapOf<RadioGroup, (Any?) -> Unit>()
    private val segmentValues  = mutableMapOf<RadioGroup, List<String>>()

    override fun createView(context: Context): View {
        return RadioGroup(context).apply {
            orientation = RadioGroup.HORIZONTAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val rg = view as? RadioGroup ?: return
        when (key) {
            "values" -> {
                val labels = when (value) {
                    is JSONArray -> (0 until value.length()).map { value.getString(it) }
                    is List<*>   -> value.map { it?.toString() ?: "" }
                    else         -> emptyList()
                }
                segmentValues[rg] = labels
                rg.removeAllViews()
                labels.forEachIndexed { i, label ->
                    val btn = RadioButton(rg.context).apply {
                        text = label
                        id = View.generateViewId()
                        setPadding(24, 16, 24, 16)
                    }
                    rg.addView(btn)
                }
            }
            "selectedIndex" -> {
                val idx = StyleEngine.toInt(value, 0)
                val child = rg.getChildAt(idx) as? RadioButton
                child?.id?.let { rg.check(it) }
            }
            "tintColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                (0 until rg.childCount).forEach { i ->
                    (rg.getChildAt(i) as? RadioButton)?.buttonTintList = android.content.res.ColorStateList.valueOf(color)
                }
            }
            "enabled" -> rg.isEnabled = value != false && value != "false"
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val rg = view as? RadioGroup ?: return
        if (event == "change") {
            changeHandlers[rg] = handler
            rg.setOnCheckedChangeListener { group, checkedId ->
                val idx = (0 until group.childCount).indexOfFirst { group.getChildAt(it).id == checkedId }
                val label = segmentValues[group]?.getOrNull(idx) ?: ""
                changeHandlers[group]?.invoke(mapOf("selectedIndex" to idx, "value" to label))
            }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val rg = view as? RadioGroup ?: return
        changeHandlers.remove(rg)
        rg.setOnCheckedChangeListener(null)
    }
}
