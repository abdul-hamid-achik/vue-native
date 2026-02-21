package com.vuenative.core

import android.content.Context
import android.view.View
import com.google.android.flexbox.FlexDirection
import com.google.android.flexbox.FlexboxLayout

class VRootFactory : NativeComponentFactory {
    override fun createView(context: Context): View {
        return FlexboxLayout(context).apply {
            flexDirection = FlexDirection.COLUMN
            layoutParams = android.view.ViewGroup.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                android.view.ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        StyleEngine.apply(key, value, view)
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        if (event == "press") {
            view.setOnClickListener { handler(null) }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        if (event == "press") view.setOnClickListener(null)
    }

    override fun insertChild(parent: View, child: View, index: Int) {
        val flex = parent as? FlexboxLayout ?: return
        val lp = StyleEngine.buildFlexLayoutParams(child)
        if (index >= flex.childCount) flex.addView(child, lp)
        else flex.addView(child, index, lp)
    }
}
