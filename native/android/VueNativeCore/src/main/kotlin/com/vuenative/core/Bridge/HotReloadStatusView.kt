package com.vuenative.core

import android.app.Activity
import android.content.Context
import android.content.pm.ApplicationInfo
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/**
 * Small, non-interactive "hot reload connection" badge shown in the
 * bottom-right corner while a dev server is configured, driven by
 * [HotReloadManager.onStatusChange]:
 *  - `Connecting` with `attempt <= 3` → orange "Connecting…"
 *  - `Connecting` with `attempt > 3` → red "Disconnected — check `vue-native dev`"
 *  - `Connected` → green "Connected", auto-hides after 2s and reappears if the
 *    connection drops again.
 *
 * [update] gates its visual badge on the *host application's* debuggability
 * (`ApplicationInfo.FLAG_DEBUGGABLE`), mirroring [ErrorOverlayView]. The other
 * half of "only when a dev server is configured" is satisfied by the caller:
 * [VueNativeActivity] only wires [HotReloadManager.onStatusChange] to this
 * view when `getDevServerUrl()` returns non-null.
 */
object HotReloadStatusView {

    private const val TAG = "vue_native_hot_reload_status"

    /** Auto-hide delay once [HotReloadStatus.Connected] is shown. */
    internal const val AUTO_HIDE_CONNECTED_MS = 2_000L

    /** Retry count above which the badge switches from "connecting" to "disconnected". */
    internal const val DISCONNECTED_AFTER_ATTEMPT = 3

    private const val COLOR_CONNECTING = 0xFFFF9800.toInt() // orange
    private const val COLOR_DISCONNECTED = 0xFFD32F2F.toInt() // red
    private const val COLOR_CONNECTED = 0xFF4CAF50.toInt() // green

    /** A resolved (color, text, auto-hide) presentation for a given [HotReloadStatus]. */
    data class Presentation(
        val backgroundColor: Int,
        val text: String,
        /** Milliseconds after which the badge should hide itself, or null to stay visible. */
        val autoHideDelayMs: Long?,
    )

    /**
     * Pure state -> presentation mapping. Has no dependency on Android views,
     * so it is directly unit-testable without Robolectric.
     */
    fun present(status: HotReloadStatus): Presentation = when (status) {
        is HotReloadStatus.Connecting ->
            if (status.attempt > DISCONNECTED_AFTER_ATTEMPT) {
                Presentation(COLOR_DISCONNECTED, "Disconnected — check `vue-native dev`", autoHideDelayMs = null)
            } else {
                Presentation(COLOR_CONNECTING, "Connecting…", autoHideDelayMs = null)
            }
        HotReloadStatus.Connected ->
            Presentation(COLOR_CONNECTED, "Connected", autoHideDelayMs = AUTO_HIDE_CONNECTED_MS)
    }

    // A fresh Handler is created per scheduled auto-hide (bound to whatever
    // Looper.getMainLooper() currently is) rather than cached once on this
    // singleton object — this object outlives any single host Activity (and,
    // under Robolectric, outlives a single test's main Looper), so caching a
    // Handler at object-init time could bind to a Looper that a later
    // host/test no longer idles. The handler is stored alongside its runnable
    // so a later cancellation calls removeCallbacks on the matching instance.
    private var pendingHide: Pair<Handler, Runnable>? = null

    private fun cancelPendingHide() {
        pendingHide?.let { (handler, runnable) -> handler.removeCallbacks(runnable) }
        pendingHide = null
    }

    /** Show/update the badge for [status]. No-op unless the host app is debuggable. */
    fun update(context: Context, status: HotReloadStatus) {
        val isHostDebuggable = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isHostDebuggable) return
        val activity = context as? Activity ?: return

        activity.runOnUiThread {
            val decorView = activity.window.decorView as? ViewGroup ?: return@runOnUiThread
            val presentation = present(status)
            val pill = decorView.findViewWithTag<TextView>(TAG) ?: createPill(activity, decorView)

            pill.text = presentation.text
            (pill.background as? GradientDrawable)?.setColor(presentation.backgroundColor)
            pill.visibility = View.VISIBLE

            cancelPendingHide()
            val delay = presentation.autoHideDelayMs
            if (delay != null) {
                val handler = Handler(Looper.getMainLooper())
                val runnable = Runnable { pill.visibility = View.GONE }
                pendingHide = handler to runnable
                handler.postDelayed(runnable, delay)
            }
        }
    }

    /** Remove the badge entirely, e.g. when the Activity hosting it is destroyed. */
    fun hide(context: Context) {
        val activity = context as? Activity ?: return
        activity.runOnUiThread {
            val decorView = activity.window.decorView as? ViewGroup ?: return@runOnUiThread
            cancelPendingHide()
            decorView.findViewWithTag<TextView>(TAG)?.let { decorView.removeView(it) }
        }
    }

    private fun createPill(activity: Activity, decorView: ViewGroup): TextView {
        val dp = activity.resources.displayMetrics.density
        val baseMargin = (16 * dp).toInt()

        val pill = TextView(activity).apply {
            tag = TAG
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setPadding((12 * dp).toInt(), (6 * dp).toInt(), (12 * dp).toInt(), (6 * dp).toInt())
            isClickable = false
            isFocusable = false
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 100f * dp
            }
        }

        val lp = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM or Gravity.END,
        ).apply { setMargins(baseMargin, baseMargin, baseMargin, baseMargin) }
        decorView.addView(pill, lp)

        // Keep the pill clear of system bars (nav bar / gesture inset).
        ViewCompat.setOnApplyWindowInsetsListener(pill) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            val params = view.layoutParams as? FrameLayout.LayoutParams
            if (params != null) {
                params.bottomMargin = baseMargin + bars.bottom
                params.rightMargin = baseMargin + bars.right
                view.layoutParams = params
            }
            insets
        }

        return pill
    }
}
