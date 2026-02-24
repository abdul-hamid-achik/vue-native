package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView

/**
 * Factory for VSectionList — a sectioned list backed by RecyclerView.
 * Children marked with the `__sectionHeader` internal prop are treated as section headers.
 * All other children are regular items grouped under the preceding header.
 */
class VSectionListFactory : NativeComponentFactory {
    private val childViews = mutableMapOf<RecyclerView, MutableList<View>>()
    private val scrollHandlers = mutableMapOf<RecyclerView, (Any?) -> Unit>()
    private val endReachedHandlers = mutableMapOf<RecyclerView, (Any?) -> Unit>()
    private val scrollListeners = mutableMapOf<RecyclerView, RecyclerView.OnScrollListener>()
    private val firedEndReached = mutableMapOf<RecyclerView, Boolean>()

    override fun createView(context: Context): View {
        val rv = RecyclerView(context).apply {
            layoutManager = LinearLayoutManager(context)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        childViews[rv] = mutableListOf()
        firedEndReached[rv] = false
        rv.adapter = VSectionListAdapter(childViews[rv]!!)
        return rv
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val rv = view as? RecyclerView ?: return
        when (key) {
            "bounces" -> {
                rv.overScrollMode = if (value == false || value == "false")
                    View.OVER_SCROLL_NEVER else View.OVER_SCROLL_ALWAYS
            }
            "showsScrollIndicator" -> {
                val show = value != false && value != "false"
                rv.isVerticalScrollBarEnabled = show
            }
            "stickySectionHeaders" -> {
                // RecyclerView sticky headers would require an ItemDecoration;
                // for now we store the preference but don't implement sticky behavior
            }
            "estimatedItemHeight" -> { /* Used for initial sizing hints */ }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val rv = view as? RecyclerView ?: return
        when (event) {
            "scroll" -> {
                scrollHandlers[rv] = handler
                ensureScrollListener(rv)
            }
            "endReached" -> {
                endReachedHandlers[rv] = handler
                ensureScrollListener(rv)
            }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val rv = view as? RecyclerView ?: return
        when (event) {
            "scroll" -> scrollHandlers.remove(rv)
            "endReached" -> endReachedHandlers.remove(rv)
        }
        if (!scrollHandlers.containsKey(rv) && !endReachedHandlers.containsKey(rv)) {
            scrollListeners.remove(rv)?.let { rv.removeOnScrollListener(it) }
        }
    }

    private fun ensureScrollListener(rv: RecyclerView) {
        if (scrollListeners.containsKey(rv)) return
        var cumulativeX = 0
        var cumulativeY = 0
        val listener = object : RecyclerView.OnScrollListener() {
            override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
                cumulativeX += dx
                cumulativeY += dy
                scrollHandlers[recyclerView]?.invoke(mapOf("x" to cumulativeX, "y" to cumulativeY))

                val lm = recyclerView.layoutManager as? LinearLayoutManager ?: return
                val totalItems = lm.itemCount
                if (totalItems == 0) return
                val lastVisible = lm.findLastVisibleItemPosition()
                val threshold = (totalItems * 0.2).toInt().coerceAtLeast(1)

                if (lastVisible >= totalItems - threshold) {
                    if (firedEndReached[recyclerView] != true) {
                        firedEndReached[recyclerView] = true
                        endReachedHandlers[recyclerView]?.invoke(null)
                    }
                } else {
                    firedEndReached[recyclerView] = false
                }
            }
        }
        scrollListeners[rv] = listener
        rv.addOnScrollListener(listener)
    }

    override fun insertChild(parent: View, child: View, index: Int) {
        val rv = parent as? RecyclerView ?: return
        val list = childViews[rv] ?: return
        if (index >= list.size) list.add(child) else list.add(index, child)
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

private class VSectionListAdapter(private val items: List<View>) : RecyclerView.Adapter<VSectionListAdapter.VH>() {
    class VH(val view: View) : RecyclerView.ViewHolder(view)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
        val v = items.getOrNull(viewType) ?: android.widget.FrameLayout(parent.context)
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
