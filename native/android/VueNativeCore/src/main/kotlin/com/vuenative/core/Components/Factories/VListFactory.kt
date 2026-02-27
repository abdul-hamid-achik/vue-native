package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView

class VListFactory : NativeComponentFactory {
    // For each RecyclerView, store child views managed by the bridge.
    // All maps are cleaned up in cleanupRecyclerView() when the view is removed.
    private val childViews = mutableMapOf<RecyclerView, MutableList<View>>()
    private val scrollHandlers = mutableMapOf<RecyclerView, (Any?) -> Unit>()
    private val endReachedHandlers = mutableMapOf<RecyclerView, (Any?) -> Unit>()
    private val scrollListeners = mutableMapOf<RecyclerView, RecyclerView.OnScrollListener>()
    private val firedEndReached = mutableMapOf<RecyclerView, Boolean>()
    private val estimatedItemHeights = mutableMapOf<RecyclerView, Int>()

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
                rv.isHorizontalScrollBarEnabled = show
            }
            "estimatedItemHeight" -> {
                val h = when (value) {
                    is Number -> value.toInt()
                    is String -> value.toIntOrNull() ?: 44
                    else -> 44
                }
                estimatedItemHeights[rv] = h
            }
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
        // Remove listener if neither handler is registered
        if (!scrollHandlers.containsKey(rv) && !endReachedHandlers.containsKey(rv)) {
            scrollListeners.remove(rv)?.let { rv.removeOnScrollListener(it) }
        }
    }

    private fun ensureScrollListener(rv: RecyclerView) {
        if (scrollListeners.containsKey(rv)) return
        // Track cumulative scroll position
        var cumulativeX = 0
        var cumulativeY = 0
        val listener = object : RecyclerView.OnScrollListener() {
            override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
                cumulativeX += dx
                cumulativeY += dy

                // Dispatch scroll event with cumulative position and dimensions
                scrollHandlers[recyclerView]?.invoke(
                    mapOf(
                        "x" to cumulativeX,
                        "y" to cumulativeY,
                        "contentWidth" to (recyclerView.computeHorizontalScrollRange()),
                        "contentHeight" to (recyclerView.computeVerticalScrollRange()),
                        "layoutWidth" to recyclerView.width,
                        "layoutHeight" to recyclerView.height,
                    )
                )

                // endReached detection (threshold = 20% from bottom)
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
                    // Reset when scrolled back up significantly
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
        val insertIdx = if (index >= list.size) list.size else index
        list.add(insertIdx, child)
        rv.adapter?.notifyItemInserted(insertIdx)
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

    /**
     * Clean up all state associated with a RecyclerView when it is removed from the tree.
     * Prevents memory leaks by clearing all map entries that reference the view.
     */
    fun cleanupRecyclerView(rv: RecyclerView) {
        scrollListeners.remove(rv)?.let { rv.removeOnScrollListener(it) }
        scrollHandlers.remove(rv)
        endReachedHandlers.remove(rv)
        firedEndReached.remove(rv)
        estimatedItemHeights.remove(rv)
        childViews.remove(rv)
        rv.adapter = null
    }

    /**
     * Called when the parent view is being destroyed. Cleans up the RecyclerView.
     */
    override fun destroyView(view: View) {
        val rv = view as? RecyclerView ?: return
        cleanupRecyclerView(rv)
    }
}

class VListAdapter(private val items: List<View>) : RecyclerView.Adapter<VListAdapter.VH>() {
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
        // Remove the previous item view from this recycled container
        container.removeAllViews()
        val itemView = items.getOrNull(position) ?: return
        // Remove from any existing parent (previous container or direct parent)
        (itemView.parent as? ViewGroup)?.removeView(itemView)
        container.addView(itemView, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ))
    }

    override fun getItemCount(): Int = items.size

    // Use a single view type so RecyclerView can reuse all ViewHolders
    override fun getItemViewType(position: Int): Int = 0
}
