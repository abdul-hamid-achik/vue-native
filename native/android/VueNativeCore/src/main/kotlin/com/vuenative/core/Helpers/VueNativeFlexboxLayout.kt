package com.vuenative.core

import android.content.Context
import android.view.View
import com.google.android.flexbox.FlexboxLayout

/**
 * FlexboxLayout variant that resolves Vue Native percentage dimensions before
 * measuring children. FlexboxLayout has percentage flex-basis, but no cross-axis
 * width/height percentages, so StyleEngine stores those values separately.
 */
open class VueNativeFlexboxLayout(context: Context) : FlexboxLayout(context) {
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val availableWidth = availableSize(widthMeasureSpec, paddingLeft + paddingRight)
        val availableHeight = availableSize(heightMeasureSpec, paddingTop + paddingBottom)
        StyleEngine.applyPercentDimensions(this, availableWidth, availableHeight)
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    private fun availableSize(measureSpec: Int, padding: Int): Int {
        if (View.MeasureSpec.getMode(measureSpec) == View.MeasureSpec.UNSPECIFIED) return -1
        return (View.MeasureSpec.getSize(measureSpec) - padding).coerceAtLeast(0)
    }
}
