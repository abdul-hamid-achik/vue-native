package com.vuenative.core

import android.content.Context
import android.graphics.Color
import android.view.View
import android.view.ViewGroup
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout

/**
 * Factory for VRefreshControl — pull-to-refresh indicator.
 *
 * Creates a SwipeRefreshLayout that wraps its children. When used as a child
 * of VScrollView, the bridge should attach this to the parent's refresh mechanism.
 * For standalone usage, this provides its own SwipeRefreshLayout.
 */
class VRefreshControlFactory : NativeComponentFactory {

    override fun createView(context: Context): View {
        // Create a zero-sized invisible view as a marker.
        // The actual refresh behavior is wired by the parent VScrollView.
        val marker = View(context).apply {
            visibility = View.GONE
            layoutParams = ViewGroup.LayoutParams(0, 0)
        }
        return marker
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        // VRefreshControl props are handled by the parent VScrollView.
        // The bridge forwards refreshing/tintColor to the parent's SwipeRefreshLayout.
        val parent = view.parent as? SwipeRefreshLayout
        when (key) {
            "refreshing" -> {
                parent?.isRefreshing = value == true || value == "true"
            }
            "tintColor" -> {
                val colorStr = value as? String ?: return
                try {
                    val color = Color.parseColor(colorStr)
                    parent?.setColorSchemeColors(color)
                } catch (_: IllegalArgumentException) {
                    // Ignore invalid color strings
                }
            }
            // "title" is iOS-only (UIRefreshControl attributedTitle)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        if (event == "refresh") {
            // Store handler on the view for the parent factory to wire up
            view.setTag(TAG_EVENT_HANDLER, handler)

            // If already inside a SwipeRefreshLayout, wire it up directly
            val parent = view.parent as? SwipeRefreshLayout
            if (parent != null) {
                parent.isEnabled = true
                parent.setOnRefreshListener { handler(null) }
            }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        if (event == "refresh") {
            view.setTag(TAG_EVENT_HANDLER, null)
            val parent = view.parent as? SwipeRefreshLayout
            if (parent != null) {
                parent.setOnRefreshListener(null)
                parent.isEnabled = false
            }
        }
    }
}
