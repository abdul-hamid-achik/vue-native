package com.vuenative.core

import android.content.Context
import android.view.View
import android.widget.TextView
import com.google.android.flexbox.FlexboxLayout

class VButtonFactory : NativeComponentFactory {
    override fun createView(context: Context): View {
        return TouchableView(context)
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val touchable = view as? TouchableView
        if (touchable == null) {
            StyleEngine.apply(key, value, view)
            return
        }

        when (key) {
            "disabled" -> {
                touchable.isDisabled = value == true || value == "true" ||
                        (value is Number && value.toInt() != 0)
            }
            "activeOpacity" -> {
                touchable.activeOpacity = when (value) {
                    is Double -> value.toFloat()
                    is Float -> value
                    is Int -> value.toFloat()
                    is String -> value.toFloatOrNull() ?: 0.7f
                    else -> 0.7f
                }
            }
            "title" -> {
                val flex = view as? FlexboxLayout
                val tv = (0 until (flex?.childCount ?: 0))
                    .mapNotNull { flex?.getChildAt(it) as? TextView }
                    .firstOrNull()
                tv?.text = value?.toString() ?: ""
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val touchable = view as? TouchableView ?: return

        when (event) {
            "press" -> touchable.onPress = { handler(null) }
            "longPress", "longpress" -> touchable.onLongPress = { handler(null) }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val touchable = view as? TouchableView ?: return

        when (event) {
            "press" -> touchable.onPress = null
            "longPress", "longpress" -> touchable.onLongPress = null
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
