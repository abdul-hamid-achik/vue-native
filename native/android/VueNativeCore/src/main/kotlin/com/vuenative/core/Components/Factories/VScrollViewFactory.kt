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

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val srf = view as? SwipeRefreshLayout ?: return
        val scroll = states[srf]?.scrollView
        when (event) {
            "refresh" -> {
                srf.isEnabled = true
                srf.setOnRefreshListener { handler(null) }
            }
            "scroll" -> {
                scroll?.viewTreeObserver?.addOnScrollChangedListener {
                    handler(mapOf(
                        "contentOffset" to mapOf("x" to scroll.scrollX, "y" to scroll.scrollY)
                    ))
                }
            }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val srf = view as? SwipeRefreshLayout ?: return
        if (event == "refresh") {
            srf.setOnRefreshListener(null)
            srf.isEnabled = false
        }
    }

    override fun insertChild(parent: View, child: View, index: Int) {
        val srf = parent as? SwipeRefreshLayout ?: return
        val content = states[srf]?.content ?: return
        val lp = StyleEngine.buildFlexLayoutParams(child)
        if (index >= content.childCount) content.addView(child, lp)
        else content.addView(child, index, lp)
    }

    override fun removeChild(parent: View, child: View) {
        val srf = parent as? SwipeRefreshLayout ?: return
        states[srf]?.content?.removeView(child)
    }
}
