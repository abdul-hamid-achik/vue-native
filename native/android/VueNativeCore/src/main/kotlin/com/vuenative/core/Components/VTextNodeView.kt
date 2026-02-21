package com.vuenative.core

import android.content.Context
import android.view.ViewGroup
import android.widget.TextView

/**
 * Represents a JS text node (created by createTextNode).
 * In Android, text nodes must be children of VText/VButton components.
 * This is a lightweight TextView that text factories use to display text node content.
 */
class VTextNodeView(context: Context) : TextView(context) {
    init {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
    }

    fun setText(text: String) {
        super.setText(text)
    }
}
