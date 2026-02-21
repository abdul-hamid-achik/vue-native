package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup

/**
 * Protocol implemented by every native component factory.
 * Mirrors Swift's NativeComponentFactory protocol.
 */
interface NativeComponentFactory {
    fun createView(context: Context): View
    fun updateProp(view: View, key: String, value: Any?)
    fun addEventListener(view: View, event: String, handler: (Any?) -> Unit)
    fun removeEventListener(view: View, event: String)

    fun insertChild(parent: View, child: View, index: Int) {
        (parent as? ViewGroup)?.let { vg ->
            val lp = child.layoutParams ?: ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            if (index >= vg.childCount) vg.addView(child, lp)
            else vg.addView(child, index, lp)
        }
    }

    fun removeChild(parent: View, child: View) {
        (parent as? ViewGroup)?.removeView(child)
    }
}
