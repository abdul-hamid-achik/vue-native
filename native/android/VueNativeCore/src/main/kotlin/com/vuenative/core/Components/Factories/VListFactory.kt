package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.flexbox.FlexboxLayout
import com.google.android.flexbox.FlexDirection

class VListFactory : NativeComponentFactory {
    // For each RecyclerView, store child views managed by the bridge
    private val childViews = mutableMapOf<RecyclerView, MutableList<View>>()
    private val scrollHandlers = mutableMapOf<RecyclerView, (Any?) -> Unit>()

    override fun createView(context: Context): View {
        val rv = RecyclerView(context).apply {
            layoutManager = LinearLayoutManager(context)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        childViews[rv] = mutableListOf()
        rv.adapter = VListAdapter(childViews[rv]!!)
        return rv
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val rv = view as? RecyclerView ?: return
        when (key) {
            "horizontal" -> {
                if (value == true) {
                    rv.layoutManager = LinearLayoutManager(rv.context, LinearLayoutManager.HORIZONTAL, false)
                }
            }
            "showsVerticalScrollIndicator", "showsHorizontalScrollIndicator" -> {}
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val rv = view as? RecyclerView ?: return
        if (event == "scroll") {
            scrollHandlers[rv] = handler
            rv.addOnScrollListener(object : RecyclerView.OnScrollListener() {
                override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
                    scrollHandlers[recyclerView]?.invoke(mapOf("dx" to dx, "dy" to dy))
                }
            })
        }
    }

    override fun removeEventListener(view: View, event: String) {}

    override fun insertChild(parent: View, child: View, index: Int) {
        val rv = parent as? RecyclerView ?: return
        val list = childViews[rv] ?: return
        if (index >= list.size) list.add(child)
        else list.add(index, child)
        rv.adapter?.notifyItemInserted(if (index >= list.size - 1) list.size - 1 else index)
    }

    override fun removeChild(parent: View, child: View) {
        val rv = parent as? RecyclerView ?: return
        val list = childViews[rv] ?: return
        val idx = list.indexOf(child)
        if (idx >= 0) {
            list.removeAt(idx)
            rv.adapter?.notifyItemRemoved(idx)
        }
    }
}

class VListAdapter(private val items: List<View>) : RecyclerView.Adapter<VListAdapter.VH>() {
    class VH(val view: View) : RecyclerView.ViewHolder(view)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
        val v = items.getOrNull(viewType) ?: android.widget.FrameLayout(parent.context)
        // Remove from any existing parent
        (v.parent as? ViewGroup)?.removeView(v)
        v.layoutParams = RecyclerView.LayoutParams(
            RecyclerView.LayoutParams.MATCH_PARENT,
            RecyclerView.LayoutParams.WRAP_CONTENT
        )
        return VH(v)
    }

    override fun onBindViewHolder(holder: VH, position: Int) {}
    override fun getItemCount(): Int = items.size
    override fun getItemViewType(position: Int): Int = position
}
