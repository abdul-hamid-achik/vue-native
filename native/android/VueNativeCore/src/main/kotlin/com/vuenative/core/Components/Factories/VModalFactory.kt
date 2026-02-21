package com.vuenative.core

import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.view.View
import android.view.ViewGroup
import android.view.Window
import com.google.android.flexbox.FlexDirection
import com.google.android.flexbox.FlexboxLayout

class VModalFactory : NativeComponentFactory {
    private val dialogs = mutableMapOf<View, Dialog>()
    private val contentContainers = mutableMapOf<View, FlexboxLayout>()
    private val dismissHandlers = mutableMapOf<View, (Any?) -> Unit>()

    override fun createView(context: Context): View {
        // Return a zero-size placeholder view
        return View(context).apply {
            layoutParams = ViewGroup.LayoutParams(0, 0)
            visibility = View.GONE
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        when (key) {
            "visible" -> {
                val show = value == true || value == "true"
                if (show) showModal(view) else dismissModal(view)
            }
            "animationType" -> {} // TODO: dialog animation
            "transparent" -> {
                if (value == true) {
                    dialogs[view]?.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
                }
            }
        }
    }

    private fun showModal(view: View) {
        val ctx = view.context
        if (dialogs[view]?.isShowing == true) return
        val dialog = Dialog(ctx, android.R.style.Theme_Translucent_NoTitleBar_Fullscreen)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
        dialog.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))

        val content = contentContainers.getOrPut(view) {
            FlexboxLayout(ctx).apply {
                flexDirection = FlexDirection.COLUMN
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            }
        }
        (content.parent as? ViewGroup)?.removeView(content)
        dialog.setContentView(content)
        dialog.setOnDismissListener { dismissHandlers[view]?.invoke(null) }
        dialog.show()
        dialogs[view] = dialog
    }

    private fun dismissModal(view: View) {
        dialogs[view]?.dismiss()
        dialogs.remove(view)
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        if (event == "dismiss") dismissHandlers[view] = handler
    }

    override fun removeEventListener(view: View, event: String) {
        if (event == "dismiss") dismissHandlers.remove(view)
    }

    override fun insertChild(parent: View, child: View, index: Int) {
        val container = contentContainers.getOrPut(parent) {
            FlexboxLayout(parent.context).apply {
                flexDirection = FlexDirection.COLUMN
            }
        }
        val lp = StyleEngine.buildFlexLayoutParams(child)
        if (index >= container.childCount) container.addView(child, lp)
        else container.addView(child, index, lp)
    }

    override fun removeChild(parent: View, child: View) {
        contentContainers[parent]?.removeView(child)
    }
}
