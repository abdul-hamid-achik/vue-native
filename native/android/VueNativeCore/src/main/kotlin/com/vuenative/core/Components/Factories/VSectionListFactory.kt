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
    private val stickyDecorations = mutableMapOf<RecyclerView, StickySectionHeaderDecoration>()

    override fun createView(context: Context): View {
        val rv = RecyclerView(context).apply {
            layoutManager = LinearLayoutManager(context)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        val items = mutableListOf<View>()
        childViews[rv] = items
        firedEndReached[rv] = false
        val decoration = StickySectionHeaderDecoration(items)
        stickyDecorations[rv] = decoration
        rv.addItemDecoration(decoration)
        rv.adapter = VSectionListAdapter(items)
        return rv
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val rv = view as? RecyclerView ?: return
        when (key) {
            "bounces" -> {
                rv.overScrollMode = if (value == false || value == "false") {
                    View.OVER_SCROLL_NEVER
                } else {
                    View.OVER_SCROLL_ALWAYS
                }
            }
            "showsScrollIndicator" -> {
                val show = value != false && value != "false"
                rv.isVerticalScrollBarEnabled = show
            }
            "stickySectionHeaders" -> {
                val enabled = value != false && value != "false"
                val decoration = stickyDecorations.getOrPut(rv) {
                    StickySectionHeaderDecoration(childViews[rv] ?: mutableListOf()).also {
                        rv.addItemDecoration(it)
                    }
                }
                decoration.enabled = enabled
                rv.invalidateItemDecorations()
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
        // NativeBridge passes a logical adapter index. RecyclerView.childCount
        // only describes currently attached (visible) rows and must not be used
        // to determine data-set order.
        val previousIndex = list.indexOf(child)
        if (previousIndex >= 0) list.removeAt(previousIndex)
        val insertIdx = index.coerceIn(0, list.size)
        list.add(insertIdx, child)
        when {
            previousIndex < 0 -> rv.adapter?.notifyItemInserted(insertIdx)
            previousIndex != insertIdx -> rv.adapter?.notifyItemMoved(previousIndex, insertIdx)
            else -> rv.adapter?.notifyItemChanged(insertIdx)
        }
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

    override fun destroyView(view: View) {
        val rv = view as? RecyclerView ?: return
        scrollListeners.remove(rv)?.let { rv.removeOnScrollListener(it) }
        stickyDecorations.remove(rv)?.let { rv.removeItemDecoration(it) }
        scrollHandlers.remove(rv)
        endReachedHandlers.remove(rv)
        firedEndReached.remove(rv)
        childViews.remove(rv)
        rv.adapter = null
    }
}

internal class StickySectionHeaderDecoration(
    private val items: List<View>,
    var enabled: Boolean = true,
) : RecyclerView.ItemDecoration() {

    fun isSectionHeader(index: Int): Boolean {
        val view = items.getOrNull(index) ?: return false
        return StyleEngine.getInternalProp("__sectionHeader", view) == true
    }

    fun headerIndexAtOrBefore(position: Int): Int? {
        if (position < 0) return null
        for (index in position downTo 0) {
            if (isSectionHeader(index)) return index
        }
        return null
    }

    fun nextHeaderIndexAfter(headerIndex: Int): Int? {
        for (index in (headerIndex + 1) until items.size) {
            if (isSectionHeader(index)) return index
        }
        return null
    }

    override fun onDrawOver(canvas: android.graphics.Canvas, parent: RecyclerView, state: RecyclerView.State) {
        if (!enabled) return
        val layoutManager = parent.layoutManager as? LinearLayoutManager ?: return
        val firstVisible = layoutManager.findFirstVisibleItemPosition()
        if (firstVisible == RecyclerView.NO_POSITION) return
        val headerIndex = headerIndexAtOrBefore(firstVisible) ?: return
        val headerView = items.getOrNull(headerIndex) ?: return

        val headerHeight = measuredHeaderHeight(headerView, parent)
        var top = 0
        nextHeaderIndexAfter(headerIndex)?.let { nextHeader ->
            childForAdapterPosition(parent, nextHeader)?.let { nextChild ->
                if (nextChild.top < headerHeight) {
                    top = nextChild.top - headerHeight
                }
            }
        }

        if (headerIndex == firstVisible) {
            val current = childForAdapterPosition(parent, headerIndex)
            if (current != null && current.top >= 0 && top == 0) {
                return
            }
        }

        val width = parent.width.coerceAtLeast(1)
        if (headerView.parent == null) {
            headerView.measure(
                View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            )
            headerView.layout(0, 0, width, headerHeight)
        }

        canvas.save()
        canvas.translate(0f, top.toFloat())
        headerView.draw(canvas)
        canvas.restore()
    }

    private fun measuredHeaderHeight(headerView: View, parent: RecyclerView): Int {
        if (headerView.height > 0) return headerView.height
        headerView.measure(
            View.MeasureSpec.makeMeasureSpec(parent.width.coerceAtLeast(1), View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        return headerView.measuredHeight.coerceAtLeast(1)
    }

    private fun childForAdapterPosition(parent: RecyclerView, position: Int): View? {
        for (index in 0 until parent.childCount) {
            val child = parent.getChildAt(index)
            if (parent.getChildAdapterPosition(child) == position) return child
        }
        return null
    }
}

private class VSectionListAdapter(private val items: List<View>) : RecyclerView.Adapter<VSectionListAdapter.VH>() {
    class VH(itemView: View) : RecyclerView.ViewHolder(itemView)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
        val container = android.widget.FrameLayout(parent.context).apply {
            layoutParams = RecyclerView.LayoutParams(
            RecyclerView.LayoutParams.MATCH_PARENT,
            RecyclerView.LayoutParams.WRAP_CONTENT
        )
        }
        return VH(container)
    }

    override fun onBindViewHolder(holder: VH, position: Int) {
        val container = holder.itemView as android.widget.FrameLayout
        container.removeAllViews()
        val itemView = items.getOrNull(position) ?: return
        (itemView.parent as? ViewGroup)?.removeView(itemView)
        container.addView(
            itemView,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )
    }

    override fun getItemCount(): Int = items.size

    // Regular rows share one type. Each section header keeps a unique type so
    // RecyclerView cannot rebind a sticky header view onto another row.
    override fun getItemViewType(position: Int): Int {
        val item = items.getOrNull(position) ?: return 0
        return if (StyleEngine.getInternalProp("__sectionHeader", item) == true) {
            HEADER_VIEW_TYPE_BASE + position
        } else {
            0
        }
    }

    companion object {
        private const val HEADER_VIEW_TYPE_BASE = 1000
    }
}
