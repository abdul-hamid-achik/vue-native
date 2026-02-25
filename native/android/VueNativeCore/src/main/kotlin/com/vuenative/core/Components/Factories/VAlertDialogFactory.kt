package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import androidx.appcompat.app.AlertDialog
import org.json.JSONArray

class VAlertDialogFactory : NativeComponentFactory {
    data class DialogProps(
        var title: String = "",
        var message: String = "",
        var buttons: List<Map<String, String>> = emptyList()
    )
    private val props = mutableMapOf<View, DialogProps>()
    private val confirmHandlers = mutableMapOf<View, (Any?) -> Unit>()
    private val cancelHandlers = mutableMapOf<View, (Any?) -> Unit>()
    private val actionHandlers = mutableMapOf<View, (Any?) -> Unit>()

    override fun createView(context: Context): View {
        return View(context).apply {
            layoutParams = ViewGroup.LayoutParams(0, 0)
            visibility = View.GONE
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val p = props.getOrPut(view) { DialogProps() }
        when (key) {
            "visible" -> {
                if (value == true || value == "true") showDialog(view, p)
            }
            "title" -> p.title = value?.toString() ?: ""
            "message" -> p.message = value?.toString() ?: ""
            "buttons" -> {
                p.buttons = when (value) {
                    is JSONArray -> (0 until value.length()).map { i ->
                        val btn = value.getJSONObject(i)
                        mapOf("label" to btn.optString("label", "OK"), "style" to btn.optString("style", "default"))
                    }
                    is List<*> -> value.filterIsInstance<Map<String, String>>()
                    else -> emptyList()
                }
            }
        }
    }

    private fun showDialog(view: View, p: DialogProps) {
        val ctx = view.context
        val builder = AlertDialog.Builder(ctx)
            .setTitle(p.title.ifEmpty { null })
            .setMessage(p.message.ifEmpty { null })

        if (p.buttons.isEmpty()) {
            builder.setPositiveButton("OK") { d, _ ->
                d.dismiss()
                confirmHandlers[view]?.invoke(null)
            }
        } else {
            p.buttons.forEach { btn ->
                val label = btn["label"] ?: "OK"
                val style = btn["style"] ?: "default"
                when (style) {
                    "cancel" -> builder.setNegativeButton(label) { d, _ ->
                        d.dismiss()
                        cancelHandlers[view]?.invoke(null)
                    }
                    "destructive" -> builder.setNeutralButton(label) { d, _ ->
                        d.dismiss()
                        confirmHandlers[view]?.invoke(mapOf("label" to label))
                    }
                    else -> builder.setPositiveButton(label) { d, _ ->
                        d.dismiss()
                        confirmHandlers[view]?.invoke(mapOf("label" to label))
                    }
                }
            }
        }
        builder.create().show()
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        when (event) {
            "confirm" -> confirmHandlers[view] = handler
            "cancel" -> cancelHandlers[view] = handler
            "action" -> actionHandlers[view] = handler
        }
    }
    override fun removeEventListener(view: View, event: String) {
        when (event) {
            "confirm" -> confirmHandlers.remove(view)
            "cancel" -> cancelHandlers.remove(view)
            "action" -> actionHandlers.remove(view)
        }
    }
}
