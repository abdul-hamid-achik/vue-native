package com.vuenative.core

import android.view.View

/**
 * Attaches gesture recognizers to a View and fires event handlers.
 */
object GestureHelper {
    fun attachTap(view: View, handler: (Any?) -> Unit) {
        view.setOnClickListener { handler(null) }
    }

    fun attachLongPress(view: View, handler: (Any?) -> Unit) {
        view.setOnLongClickListener { handler(null); true }
    }
}
