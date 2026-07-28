package com.vuenative.core

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Inspector module — backs the runtime `useInspector` composable
 * (`packages/runtime/src/composables/useInspector.ts`).
 *
 * `dumpTree` serializes the live native view hierarchy as a JSON tree of the
 * shape `{ id, type, frame: { x, y, width, height }, children: [...] }`, where
 * `frame` is expressed in the parent's coordinate space (matching `View.left`,
 * `View.top`, `View.width`, `View.height`).
 *
 * The tree is derived from the bridge's logical node registry (`nodeViews`,
 * `nodeTypes`, `nodeChildren`, `nodeParents`) rather than the raw `ViewGroup`
 * child list. The logical registry is the source of truth for node ids and
 * types and stays correct for components whose physical view hierarchy differs
 * from their logical children (e.g. RecyclerView-backed VList items, scroll and
 * modal content containers).
 */
class InspectorModule : NativeModule {
    override val moduleName = "Inspector"

    override fun initialize(context: Context, bridge: NativeBridge) {
        // No setup required — the tree is read from the bridge on demand.
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "dumpTree" -> {
                val rootId = findRootId(bridge)
                if (rootId == null) {
                    // An empty tree is a valid state (nothing mounted yet), not an error.
                    callback(null, null)
                    return
                }
                callback(buildNode(bridge, rootId, mutableSetOf()), null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }

    /**
     * Choose the root node to dump. Prefers the node backing [NativeBridge.rootView]
     * (the mounted root), falling back to the lowest-id node without a parent so
     * the dump is deterministic when the root view has not been set yet.
     */
    private fun findRootId(bridge: NativeBridge): Int? {
        val rootView = bridge.rootView
        if (rootView != null) {
            bridge.nodeViews.entries.firstOrNull { it.value === rootView }?.let { return it.key }
        }
        return bridge.nodeViews.keys
            .filter { bridge.nodeParents[it] == null }
            .minOrNull()
    }

    /** Recursively serialize one node and its logical children. */
    private fun buildNode(bridge: NativeBridge, nodeId: Int, visited: MutableSet<Int>): JSONObject {
        visited.add(nodeId)
        val view = bridge.nodeViews[nodeId]

        val node = JSONObject()
        node.put("id", nodeId)
        node.put("type", bridge.nodeTypes[nodeId] ?: "Unknown")

        if (view != null) {
            node.put(
                "frame",
                JSONObject()
                    .put("x", view.left)
                    .put("y", view.top)
                    .put("width", view.width)
                    .put("height", view.height)
            )
        }

        val children = JSONArray()
        for (childId in bridge.nodeChildren[nodeId].orEmpty()) {
            // Guard against cycles in a corrupted registry.
            if (childId in visited) continue
            children.put(buildNode(bridge, childId, visited))
        }
        node.put("children", children)

        return node
    }
}
