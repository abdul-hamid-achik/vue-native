package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.ScrollView
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import com.google.android.flexbox.FlexDirection
import com.google.android.flexbox.FlexboxLayout

class VScrollViewFactory : NativeComponentFactory {

    // Tracks the inner ScrollView and content FlexboxLayout per SwipeRefreshLayout root
    private data class ScrollState(val scrollView: ScrollView, val content: FlexboxLayout)
    private val states = mutableMapOf<SwipeRefreshLayout, ScrollState>()

    override fun createView(context: Context): View {
        val content = FlexboxLayout(context).apply {
            flexDirection = FlexDirection.COLUMN
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        val scroll = ScrollView(context).apply {
            isFillViewport = true
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        scroll.addView(content)

        val srf = SwipeRefreshLayout(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            // Disabled by default; enabled when @refresh listener is added
            isEnabled = false
        }
        srf.addView(scroll)
        states[srf] = ScrollState(scroll, content)
        return srf
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val srf = view as? SwipeRefreshLayout ?: return
        val scroll = states[srf]?.scrollView
        when (key) {
            "refreshing" -> {
                srf.isRefreshing = value == true || value == "true"
            }
            "showsVerticalScrollIndicator" -> {
                scroll?.isVerticalScrollBarEnabled = value != false && value != "false"
            }
            "showsHorizontalScrollIndicator" -> {
                scroll?.isHorizontalScrollBarEnabled = value != false && value != "false"
            }
            "scrollEnabled" -> {
                // ScrollView doesn't expose a direct enable toggle; no-op
            }
            else -> scroll?.let { StyleEngine.apply(key, value, it) }
        }
    }

    private val scrollThrottles = mutableMapOf<SwipeRefreshLayout, EventThrottle>()
    private val scrollListeners = mutableMapOf<SwipeRefreshLayout, android.view.ViewTreeObserver.OnScrollChangedListener>()

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val srf = view as? SwipeRefreshLayout ?: return
        val scroll = states[srf]?.scrollView
        when (event) {
            "refresh" -> {
                srf.isEnabled = true
                srf.setOnRefreshListener { handler(null) }
            }
            "scroll" -> {
                val throttle = EventThrottle(intervalMs = 16L, handler = handler)
                scrollThrottles[srf] = throttle
                val listener = android.view.ViewTreeObserver.OnScrollChangedListener {
                    val child = if (scroll != null && scroll.childCount > 0) scroll.getChildAt(0) else null
                    throttle.fire(mapOf(
                        "x" to (scroll?.scrollX ?: 0),
                        "y" to (scroll?.scrollY ?: 0),
                        "contentWidth" to (child?.width ?: scroll?.width ?: 0),
                        "contentHeight" to (child?.height ?: scroll?.height ?: 0),
                        "layoutWidth" to (scroll?.width ?: 0),
                        "layoutHeight" to (scroll?.height ?: 0),
                    ))
                }
                scrollListeners[srf] = listener
                scroll?.viewTreeObserver?.addOnScrollChangedListener(listener)
            }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val srf = view as? SwipeRefreshLayout ?: return
        when (event) {
            "refresh" -> {
                srf.setOnRefreshListener(null)
                srf.isEnabled = false
            }
            "scroll" -> {
                scrollListeners.remove(srf)?.let { listener ->
                    states[srf]?.scrollView?.viewTreeObserver?.removeOnScrollChangedListener(listener)
                }
                scrollThrottles.remove(srf)?.cancel()
            }
        }
    }

    override fun insertChild(parent: View, child: View, index: Int) {
        val srf = parent as? SwipeRefreshLayout ?: return
        val content = states[srf]?.content ?: return
        val lp = StyleEngine.buildFlexLayoutParams(child)
        if (index >= content.childCount) {
            content.addView(child, lp)
        } else {
            content.addView(child, index, lp)
        }
    }

    override fun removeChild(parent: View, child: View) {
        val srf = parent as? SwipeRefreshLayout ?: return
        states[srf]?.content?.removeView(child)
    }
}
