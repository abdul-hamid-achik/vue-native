package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import com.google.android.flexbox.FlexDirection
import com.google.android.flexbox.FlexboxLayout

class VKeyboardAvoidingFactory : NativeComponentFactory {
    override fun createView(context: Context): View {
        val flex = FlexboxLayout(context).apply {
            flexDirection = FlexDirection.COLUMN
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        // The Activity sets android:windowSoftInputMode="adjustResize" which
        // makes the system handle keyboard avoidance automatically on Android.
        return flex
    }
    override fun updateProp(view: View, key: String, value: Any?) = StyleEngine.apply(key, value, view)
    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {}
    override fun removeEventListener(view: View, event: String) {}
    override fun insertChild(parent: View, child: View, index: Int) {
        val flex = parent as? FlexboxLayout ?: return
        val lp = StyleEngine.buildFlexLayoutParams(child)
        if (index >= flex.childCount) flex.addView(child, lp) else flex.addView(child, index, lp)
    }
}
