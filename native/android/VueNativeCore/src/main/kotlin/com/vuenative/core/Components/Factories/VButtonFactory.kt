package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import com.google.android.flexbox.AlignItems
import com.google.android.flexbox.FlexDirection
import com.google.android.flexbox.FlexboxLayout
import com.google.android.flexbox.JustifyContent

class VButtonFactory : NativeComponentFactory {
    override fun createView(context: Context): View {
        // VButton is a pressable FlexboxLayout (can contain VText children)
        return FlexboxLayout(context).apply {
            flexDirection = FlexDirection.ROW
            alignItems = AlignItems.CENTER
            justifyContent = JustifyContent.CENTER
            isClickable = true
            isFocusable = true
            // Add ripple feedback
            val outValue = android.util.TypedValue()
            context.theme.resolveAttribute(android.R.attr.selectableItemBackground, outValue, true)
            foreground = context.getDrawable(outValue.resourceId)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        when (key) {
            "disabled" -> {
                view.isEnabled = !(value == true || value == "true")
                view.alpha = if (!view.isEnabled) 0.4f else 1f
            }
            "onPress" -> { /* handled via addEventListener */ }
            "title" -> {
                // If the button has a TextView child, update it
                val flex = view as? FlexboxLayout
                val tv = (0 until (flex?.childCount ?: 0)).mapNotNull { flex?.getChildAt(it) as? TextView }.firstOrNull()
                tv?.text = value?.toString() ?: ""
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        when (event) {
            "press" -> view.setOnClickListener { if (view.isEnabled) handler(null) }
            "longPress" -> view.setOnLongClickListener { if (view.isEnabled) { handler(null); true } else false }
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
        (parent as? FlexboxLayout)?.removeView(child)
    }
}
