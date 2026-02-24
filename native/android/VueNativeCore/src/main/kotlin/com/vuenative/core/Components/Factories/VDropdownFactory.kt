package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Spinner
import org.json.JSONArray

class VDropdownFactory : NativeComponentFactory {
    private val changeHandlers = mutableMapOf<Spinner, (Any?) -> Unit>()
    private val optionValues = mutableMapOf<Spinner, List<String>>()
    private val optionLabels = mutableMapOf<Spinner, List<String>>()

    override fun createView(context: Context): View {
        return Spinner(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val spinner = view as? Spinner ?: return
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

                val labels = items.map { it.first }
                val values = items.map { it.second }
                optionLabels[spinner] = labels
                optionValues[spinner] = values

                // Add placeholder if set
                val placeholder = spinner.tag as? String ?: "Select..."
                val displayLabels = listOf(placeholder) + labels

                val adapter = ArrayAdapter(
                    spinner.context,
                    android.R.layout.simple_spinner_item,
                    displayLabels
                ).apply {
                    setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                }
                spinner.adapter = adapter

                // Re-apply selection
                applySelection(spinner)
            }
            "selectedValue" -> {
                spinner.setTag(android.R.id.text1, value?.toString())
                applySelection(spinner)
            }
            "placeholder" -> {
                spinner.tag = value?.toString() ?: "Select..."
                // Rebuild adapter with new placeholder
                val labels = optionLabels[spinner] ?: return
                val displayLabels = listOf(value?.toString() ?: "Select...") + labels
                val adapter = ArrayAdapter(
                    spinner.context,
                    android.R.layout.simple_spinner_item,
                    displayLabels
                ).apply {
                    setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                }
                spinner.adapter = adapter
            }
            "disabled" -> {
                spinner.isEnabled = value != true && value != "true"
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val spinner = view as? Spinner ?: return
        if (event == "change") {
            changeHandlers[spinner] = handler
            spinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(parent: AdapterView<*>?, v: View?, position: Int, id: Long) {
                    // Position 0 is placeholder
                    if (position == 0) return
                    val values = optionValues[spinner] ?: return
                    val labels = optionLabels[spinner] ?: return
                    val idx = position - 1
                    if (idx < values.size) {
                        changeHandlers[spinner]?.invoke(mapOf(
                            "value" to values[idx],
                            "label" to labels[idx]
                        ))
                    }
                }
                override fun onNothingSelected(parent: AdapterView<*>?) {}
            }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val spinner = view as? Spinner ?: return
        if (event == "change") {
            changeHandlers.remove(spinner)
            spinner.onItemSelectedListener = null
        }
    }

    private fun applySelection(spinner: Spinner) {
        val selected = spinner.getTag(android.R.id.text1) as? String ?: return
        val values = optionValues[spinner] ?: return
        val idx = values.indexOf(selected)
        if (idx >= 0) {
            spinner.setSelection(idx + 1) // +1 for placeholder
        }
    }
}
