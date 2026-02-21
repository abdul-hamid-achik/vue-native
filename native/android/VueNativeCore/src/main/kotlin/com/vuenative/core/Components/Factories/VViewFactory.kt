package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import com.google.android.flexbox.FlexDirection
import com.google.android.flexbox.FlexboxLayout

class VViewFactory : NativeComponentFactory {
    override fun createView(context: Context): View {
        return FlexboxLayout(context).apply {
            flexDirection = FlexDirection.COLUMN
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        StyleEngine.apply(key, value, view)
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        when (event) {
            "press" -> view.setOnClickListener { handler(null) }
            "longPress" -> view.setOnLongClickListener { handler(null); true }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        when (event) {
            "press" -> view.setOnClickListener(null)
            "longPress" -> view.setOnLongClickListener(null)
        }
    }

    override fun insertChild(parent: View, child: View, index: Int) {
        val flex = parent as? FlexboxLayout ?: return
        val lp = StyleEngine.buildFlexLayoutParams(child)
        if (index >= flex.childCount) flex.addView(child, lp)
        else flex.addView(child, index, lp)
    }

    override fun removeChild(parent: View, child: View) {
        (parent as? ViewGroup)?.removeView(child)
    }
}
