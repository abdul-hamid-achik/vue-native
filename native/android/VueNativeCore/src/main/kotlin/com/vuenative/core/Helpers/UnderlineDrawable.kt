package com.vuenative.core

import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.Drawable

/**
 * A Material-style underline background for text inputs. Draws a thin line at
 * the bottom edge that thickens and recolors when the host view is focused.
 *
 * The drawable is stateful: the EditText propagates its focused drawable state
 * automatically, so no extra focus listener is required for the visual feedback.
 */
class UnderlineDrawable(
    private val baseColor: Int,
    private val focusedColor: Int,
    private val baseHeightPx: Int,
    private val focusedHeightPx: Int,
) : Drawable() {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var focused = false

    override fun draw(canvas: Canvas) {
        val height = if (focused) focusedHeightPx else baseHeightPx
        paint.color = if (focused) focusedColor else baseColor
        val bottom = bounds.bottom.toFloat()
        canvas.drawRect(
            bounds.left.toFloat(),
            bottom - height,
            bounds.right.toFloat(),
            bottom,
            paint,
        )
    }

    override fun onStateChange(state: IntArray): Boolean {
        val nowFocused = state.contains(android.R.attr.state_focused)
        if (nowFocused != focused) {
            focused = nowFocused
            invalidateSelf()
            return true
        }
        return false
    }

    override fun isStateful(): Boolean = true

    override fun setAlpha(alpha: Int) {
        paint.alpha = alpha
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        paint.colorFilter = colorFilter
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
}
