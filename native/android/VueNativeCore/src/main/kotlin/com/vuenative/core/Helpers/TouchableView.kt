package com.vuenative.core

import android.content.Context
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.ViewGroup
import com.google.android.flexbox.AlignItems
import com.google.android.flexbox.FlexDirection
import com.google.android.flexbox.FlexboxLayout
import com.google.android.flexbox.JustifyContent

/**
 * Custom FlexboxLayout subclass that provides button-like touch behavior
 * with configurable active opacity and support for press and long press events.
 * Mirrors the Swift TouchableView (UIView subclass) for Android.
 */
class TouchableView(context: Context) : FlexboxLayout(context) {

    /** The opacity to apply when the user is pressing the view. */
    var activeOpacity: Float = 1.0f

    /** Called when a tap completes within the view bounds. */
    var onPress: (() -> Unit)? = null

    /** Called when a long press gesture is recognized. */
    var onLongPress: (() -> Unit)? = null

    /** Whether touch interactions are disabled. */
    var isDisabled: Boolean = false
        set(value) {
            field = value
            isEnabled = !value
            isClickable = !value
            alpha = if (value) 0.4f else 1.0f
        }

    private var isTouchInside: Boolean = false
    private var longPressDetected: Boolean = false

    private val gestureDetector: GestureDetector

    init {
        flexDirection = FlexDirection.ROW
        alignItems = AlignItems.CENTER
        justifyContent = JustifyContent.CENTER
        isClickable = true
        isFocusable = true
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )

        gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
            override fun onLongPress(e: MotionEvent) {
                if (!isDisabled) {
                    longPressDetected = true
                    this@TouchableView.onLongPress?.invoke()
                }
            }
        })
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (isDisabled) return false

        gestureDetector.onTouchEvent(event)

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                isTouchInside = true
                longPressDetected = false
                animate().alpha(activeOpacity).setDuration(100).start()
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                val wasInside = isTouchInside
                isTouchInside = event.x >= 0 && event.x <= width &&
                        event.y >= 0 && event.y <= height

                if (wasInside != isTouchInside) {
                    val targetAlpha = if (isTouchInside) activeOpacity else 1.0f
                    animate().alpha(targetAlpha).setDuration(100).start()
                }
            }

            MotionEvent.ACTION_UP -> {
                animate().alpha(1.0f).setDuration(150).start()
                if (isTouchInside && !longPressDetected) {
                    onPress?.invoke()
                }
                isTouchInside = false
                longPressDetected = false
            }

            MotionEvent.ACTION_CANCEL -> {
                animate().alpha(1.0f).setDuration(150).start()
                isTouchInside = false
                longPressDetected = false
            }
        }

        return super.onTouchEvent(event)
    }
}
