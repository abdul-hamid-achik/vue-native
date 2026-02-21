package com.vuenative.core

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
import androidx.appcompat.app.AppCompatActivity

/**
 * Full-screen debug error overlay shown in DEBUG builds when a JS error occurs.
 */
object ErrorOverlayView {

    fun show(context: Context, error: String) {
        val activity = context as? AppCompatActivity ?: return
        activity.runOnUiThread {
            val decorView = activity.window.decorView as? ViewGroup ?: return@runOnUiThread

            // Remove existing overlay
            decorView.findViewWithTag<FrameLayout>("vue_native_error_overlay")?.let {
                decorView.removeView(it)
            }

            val dp = context.resources.displayMetrics.density

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
                setPadding(0, 0, 0, (12 * dp).toInt())
            }

            val scroll = ScrollView(context).apply {
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f
                )
            }

            val errorText = TextView(context).apply {
                text = error
                setTextColor(Color.parseColor("#FFCC00"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                setTypeface(Typeface.MONOSPACE)
                setPadding((8 * dp).toInt(), (8 * dp).toInt(), (8 * dp).toInt(), (8 * dp).toInt())
            }

            val dismiss = Button(context).apply {
                text = "Dismiss"
                setOnClickListener { decorView.removeView(overlay) }
            }

            scroll.addView(errorText)
            card.addView(title)
            card.addView(scroll)
            card.addView(dismiss)

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
