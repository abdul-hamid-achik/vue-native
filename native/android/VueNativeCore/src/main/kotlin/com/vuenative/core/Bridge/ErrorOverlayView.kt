package com.vuenative.core

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONObject

/**
 * Full-screen debug error overlay shown in DEBUG builds when a JS error occurs.
 *
 * The error payload arrives in one of two shapes:
 *  - A structured JSON object emitted by the runtime `app.config.errorHandler`
 *    (`{ message, stack, componentName, info }` — see `packages/runtime/src/index.ts`,
 *    forwarded through `__VN_handleError`).
 *  - A plain string for failures that happen before the runtime error handler is
 *    live (e.g. a bundle load/eval error from [JSRuntime.loadBundle]).
 *
 * The overlay renders the message in bold, the component name when present, and
 * the stack trace in a scrollable monospace block, plus Reload and Dismiss
 * buttons. Reload re-triggers the bundle load: it invokes the configurable
 * [onReload] callback when supplied, and otherwise falls back to recreating the
 * host Activity (which reloads the bundle from scratch).
 */
object ErrorOverlayView {

    /** A parsed JS error ready for structured display. */
    data class ParsedError(
        val message: String,
        val stack: String?,
        val componentName: String?,
    )

    /**
     * Parse an error payload into its structured parts. Accepts the JSON emitted
     * by the JS error handler (`{ message, stack, componentName }`) and falls back
     * to treating the whole string as the message for plain-text errors.
     */
    fun parse(error: String): ParsedError {
        val trimmed = error.trim()
        if (trimmed.startsWith("{")) {
            try {
                val json = JSONObject(trimmed)
                if (json.has("message")) {
                    val message = json.optString("message", "")
                    return ParsedError(
                        message = message.ifBlank { trimmed },
                        stack = json.optString("stack", "").ifBlank { null },
                        componentName = json.optString("componentName", "").ifBlank { null },
                    )
                }
            } catch (_: Exception) {
                // Not valid JSON — fall through to plain-text handling.
            }
        }
        return ParsedError(message = error, stack = null, componentName = null)
    }

    fun show(context: Context, error: String, onReload: (() -> Unit)? = null) {
        val activity = context as? Activity ?: return
        activity.runOnUiThread {
            val decorView = activity.window.decorView as? ViewGroup ?: return@runOnUiThread

            // Remove existing overlay
            decorView.findViewWithTag<FrameLayout>("vue_native_error_overlay")?.let {
                decorView.removeView(it)
            }

            val dp = context.resources.displayMetrics.density
            val parsed = parse(error)

            val overlay = FrameLayout(context).apply {
                tag = "vue_native_error_overlay"
                setBackgroundColor(Color.parseColor("#CC1A1A1A"))
                layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            }

            val card = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(Color.parseColor("#FF1A1A1A"))
                setPadding(
                    (16 * dp).toInt(), (16 * dp).toInt(),
                    (16 * dp).toInt(), (16 * dp).toInt()
                )
            }

            val title = TextView(context).apply {
                text = "Vue Native JS Error"
                setTextColor(Color.RED)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                setTypeface(null, Typeface.BOLD)
                setPadding(0, 0, 0, (8 * dp).toInt())
            }
            card.addView(title)

            // Component name — only rendered when the payload carries one.
            if (!parsed.componentName.isNullOrBlank()) {
                val component = TextView(context).apply {
                    tag = "vue_native_error_component"
                    text = "Component: ${parsed.componentName}"
                    setTextColor(Color.parseColor("#888888"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                    setPadding(0, 0, 0, (8 * dp).toInt())
                }
                card.addView(component)
            }

            // Message — bold so it stands out from the stack trace.
            val message = TextView(context).apply {
                tag = "vue_native_error_message"
                text = parsed.message
                setTextColor(Color.parseColor("#FFCC00"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                typeface = Typeface.DEFAULT_BOLD
                setPadding(0, 0, 0, (8 * dp).toInt())
            }
            card.addView(message)

            // Stack trace — monospace and scrollable.
            val scroll = ScrollView(context).apply {
                tag = "vue_native_error_scroll"
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f
                )
            }
            val stackText = TextView(context).apply {
                tag = "vue_native_error_stack"
                text = parsed.stack ?: ""
                setTextColor(Color.parseColor("#CCCCCC"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                setTypeface(Typeface.MONOSPACE)
                setPadding((8 * dp).toInt(), (8 * dp).toInt(), (8 * dp).toInt(), (8 * dp).toInt())
            }
            scroll.addView(stackText)
            card.addView(scroll)

            // Button row: Reload (re-triggers the bundle load) + Dismiss.
            val buttonRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, (8 * dp).toInt(), 0, 0)
            }

            val reload = Button(context).apply {
                tag = "vue_native_error_reload"
                text = "Reload"
                setOnClickListener {
                    decorView.removeView(overlay)
                    val reloadAction = onReload
                    if (reloadAction != null) {
                        reloadAction()
                    } else {
                        activity.recreate()
                    }
                }
            }
            val dismiss = Button(context).apply {
                tag = "vue_native_error_dismiss"
                text = "Dismiss"
                setOnClickListener { decorView.removeView(overlay) }
            }
            buttonRow.addView(reload)
            buttonRow.addView(dismiss)
            card.addView(buttonRow)

            val lp = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                (400 * dp).toInt(),
                Gravity.CENTER
            ).apply {
                setMargins((16 * dp).toInt(), 0, (16 * dp).toInt(), 0)
            }
            overlay.addView(card, lp)
            decorView.addView(overlay)
        }
    }
}
