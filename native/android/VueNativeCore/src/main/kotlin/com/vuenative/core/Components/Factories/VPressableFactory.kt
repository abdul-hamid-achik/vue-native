package com.vuenative.core

import android.content.Context
import android.view.MotionEvent
import android.view.View
import com.google.android.flexbox.FlexboxLayout

/**
 * Factory for VPressable — a generic pressable container component.
 *
 * Like VButton but without built-in text/label support. Uses PressableView,
 * a subclass of TouchableView that adds pressIn/pressOut callbacks.
 */
class VPressableFactory : NativeComponentFactory {

    override fun createView(context: Context): View {
        return PressableView(context)
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val pressable = view as? PressableView
        if (pressable == null) {
            StyleEngine.apply(key, value, view)
            return
        }

        when (key) {
            "disabled" -> {
                pressable.isDisabled = value == true || value == "true" ||
                        (value is Number && value.toInt() != 0)
            }
            "activeOpacity" -> {
                pressable.activeOpacity = when (value) {
                    is Double -> value.toFloat()
                    is Float -> value
                    is Int -> value.toFloat()
                    is String -> value.toFloatOrNull() ?: 0.7f
                    else -> 0.7f
                }
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val pressable = view as? PressableView ?: return

        when (event) {
            "press" -> pressable.onPress = { handler(null) }
            "longPress", "longpress" -> pressable.onLongPress = { handler(null) }
            "pressIn", "pressin" -> pressable.onPressIn = { handler(null) }
            "pressOut", "pressout" -> pressable.onPressOut = { handler(null) }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val pressable = view as? PressableView ?: return

        when (event) {
            "press" -> pressable.onPress = null
            "longPress", "longpress" -> pressable.onLongPress = null
            "pressIn", "pressin" -> pressable.onPressIn = null
            "pressOut", "pressout" -> pressable.onPressOut = null
        }
    }

    override fun insertChild(parent: View, child: View, index: Int) {
        val flex = parent as? FlexboxLayout ?: return
        val lp = StyleEngine.buildFlexLayoutParams(child)
        if (index >= flex.childCount) {
            flex.addView(child, lp)
        } else {
            flex.addView(child, index, lp)
        }
    }

    override fun removeChild(parent: View, child: View) {
        (parent as? FlexboxLayout)?.removeView(child)
    }
}

/**
 * Extension of TouchableView that adds pressIn and pressOut callbacks.
 * Fires pressIn when a touch begins and pressOut when the touch ends or is cancelled.
 */
class PressableView(context: android.content.Context) : TouchableView(context) {

    /** Called when a touch begins inside the view bounds. */
    var onPressIn: (() -> Unit)? = null

    /** Called when a touch ends or is cancelled. */
    var onPressOut: (() -> Unit)? = null

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (isDisabled) return false

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                onPressIn?.invoke()
            }
            MotionEvent.ACTION_UP -> {
                onPressOut?.invoke()
            }
            MotionEvent.ACTION_CANCEL -> {
                onPressOut?.invoke()
            }
        }

        return super.onTouchEvent(event)
    }
}
