package com.vuenative.core

import android.content.Context
import android.graphics.Color
import android.view.View
import android.view.ViewGroup
import android.widget.TextView

class VTextFactory : NativeComponentFactory {
    override fun createView(context: Context): View {
        return TextView(context).apply {
            setTextColor(Color.BLACK)
            textSize = 14f
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val tv = view as? TextView ?: return
        when (key) {
            "text" -> tv.text = value?.toString() ?: ""
            "numberOfLines" -> {
                val n = StyleEngine.toInt(value, 0)
                tv.maxLines = if (n == 0) Int.MAX_VALUE else n
                tv.ellipsize = if (n > 0) android.text.TextUtils.TruncateAt.END else null
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        if (event == "press") view.setOnClickListener { handler(null) }
    }

    override fun removeEventListener(view: View, event: String) {
        if (event == "press") view.setOnClickListener(null)
    }

    // VText renders text node children by concatenating their text
    override fun insertChild(parent: View, child: View, index: Int) {
        if (child is VTextNodeView) {
            (parent as? TextView)?.append(child.text)
        }
        // Don't add as visual child
    }

    override fun removeChild(parent: View, child: View) {
        // Text is managed as a string — no visual child to remove
    }
}
