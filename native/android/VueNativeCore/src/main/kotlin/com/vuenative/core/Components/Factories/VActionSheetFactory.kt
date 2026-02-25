package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import androidx.appcompat.app.AlertDialog
import org.json.JSONArray

class VActionSheetFactory : NativeComponentFactory {
    data class SheetProps(
        var title: String = "",
        var message: String = "",
        var actions: List<Map<String, String>> = emptyList()
    )
    private val props = mutableMapOf<View, SheetProps>()
    private val actionHandlers = mutableMapOf<View, (Any?) -> Unit>()
    private val cancelHandlers = mutableMapOf<View, (Any?) -> Unit>()

    override fun createView(context: Context): View = View(context).apply {
        layoutParams = ViewGroup.LayoutParams(0, 0)
        visibility = View.GONE
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val p = props.getOrPut(view) { SheetProps() }
        when (key) {
            "visible" -> {
                if (value == true || value == "true") showSheet(view, p)
            }
            "title" -> p.title = value?.toString() ?: ""
            "message" -> p.message = value?.toString() ?: ""
            "actions" -> {
                p.actions = when (value) {
                    is JSONArray -> (0 until value.length()).map { i ->
                        val a = value.getJSONObject(i)
                        mapOf("label" to a.optString("label", ""), "style" to a.optString("style", "default"))
                    }
                    is List<*> -> value.filterIsInstance<Map<String, String>>()
                    else -> emptyList()
                }
            }
        }
    }

    private fun showSheet(view: View, p: SheetProps) {
        val ctx = view.context
        val items = p.actions.map { it["label"] ?: "" }.toTypedArray()
        val cancelIdx = p.actions.indexOfFirst { it["style"] == "cancel" }

        AlertDialog.Builder(ctx)
            .setTitle(p.title.ifEmpty { null })
            .setMessage(p.message.ifEmpty { null })
            .setItems(items) { _, which ->
                val action = p.actions.getOrNull(which)
                if (action?.get("style") == "cancel") {
                    cancelHandlers[view]?.invoke(null)
                } else {
                    actionHandlers[view]?.invoke(mapOf("label" to (action?.get("label") ?: ""), "index" to which))
                }
            }
            .setNegativeButton("Cancel") { d, _ ->
                d.dismiss()
                cancelHandlers[view]?.invoke(null)
            }
            .show()
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        when (event) {
            "action" -> actionHandlers[view] = handler
            "cancel" -> cancelHandlers[view] = handler
        }
    }
    override fun removeEventListener(view: View, event: String) {
        when (event) {
            "action" -> actionHandlers.remove(view)
            "cancel" -> cancelHandlers.remove(view)
        }
    }
}
