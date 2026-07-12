package com.vuenative.core

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject

/**
 * Receives batched JS operations, dispatches them to the native view system,
 * and provides event firing back to JS.
 */
class NativeBridge(private val context: Context) {

    companion object {
        private const val TAG = "VueNative-Bridge"

        /** Operations that mutate the view tree and require a layout pass. */
        private val treeMutationOps = setOf(
            "create", "createText", "appendChild", "insertBefore", "removeChild",
            "setRootView", "setText", "setElementText"
        )

        /** Style properties that affect layout and require a layout pass when changed. */
        private val layoutAffectingStyles = setOf(
            "width", "height", "minWidth", "minHeight", "maxWidth", "maxHeight",
            "flex", "flexGrow", "flexShrink", "flexBasis", "flexDirection",
            "flexWrap", "alignItems", "alignSelf", "alignContent", "justifyContent",
            "padding", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
            "paddingHorizontal", "paddingVertical", "paddingStart", "paddingEnd",
            "margin", "marginTop", "marginRight", "marginBottom", "marginLeft",
            "marginHorizontal", "marginVertical", "marginStart", "marginEnd",
            "gap", "rowGap", "columnGap",
            "position", "top", "right", "bottom", "left", "start", "end",
            "aspectRatio", "display", "overflow", "direction",
        )
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    // -- View registry --
    /** Maps node IDs to native Views. Accessed only on main thread. */
    val nodeViews = mutableMapOf<Int, View>()

    /** Maps node IDs to component type strings. Accessed only on main thread. */
    val nodeTypes = mutableMapOf<Int, String>()

    /** Maps "nodeId:eventName" to handler. Accessed only on main thread. */
    val eventHandlers = mutableMapOf<String, (Any?) -> Unit>()

    /** Reverse index: maps nodeId to the set of event keys registered for that node.
     *  Enables O(k) cleanup where k = handlers per node, instead of O(n) full scan. */
    private val eventKeysPerNode = mutableMapOf<Int, MutableSet<String>>()

    /** Maps child nodeId to parent nodeId. Accessed only on main thread. */
    val nodeParents = mutableMapOf<Int, Int>()

    /** Reverse index: maps parent nodeId to ordered list of child nodeIds. O(1) children lookup. */
    val nodeChildren = mutableMapOf<Int, MutableList<Int>>()

    /** The root view of the tree — set when __ROOT__ node is made the root view. */
    var rootView: View? = null

    /** The container view from the host Activity — where the root view is attached. */
    var hostContainer: ViewGroup? = null

    // -- Teleport support --
    /** Maps teleport marker IDs for cleanup */
    private val teleportMarkers = mutableMapOf<Int, Pair<Int, Int>>()

    /** Maps parent node IDs to their teleport containers */
    private val teleportContainers = mutableMapOf<Int, ViewGroup>()

    /** Modal container for teleporting modals */
    private val modalContainer: FrameLayout by lazy {
        FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            isClickable = true
            isFocusable = false
        }
    }

    /** Called when native fires an event to JS (nodeId, eventName, payloadJson). */
    var onFireEvent: ((nodeId: Int, eventName: String, payloadJson: String) -> Unit)? = null

    /** Called when a module dispatches a global event to JS (eventName, payloadJson). */
    var onDispatchGlobalEvent: ((eventName: String, payloadJson: String) -> Unit)? = null

    @Volatile
    private var isActive = true

    /**
     * Identifies the JavaScript world that owns asynchronous native-module
     * callbacks. Hot reload reuses this bridge but resets JavaScript callback
     * IDs, so a completion from the previous bundle must not resolve a Promise
     * created by the replacement bundle with the same ID.
     *
     * Access is confined to the main thread. Module completions post back to
     * [mainHandler] before comparing their captured generation.
     */
    private var nativeCallbackGeneration = 0L

    private val componentRegistry: ComponentRegistry by lazy { ComponentRegistry.getInstance(context) }

    // -------------------------------------------------------------------------
    // Operation processing — called from JS thread
    // -------------------------------------------------------------------------

    /** Called from JS thread via __VN_flushOperations. Parses JSON and dispatches to main. */
    fun processOperations(json: String) {
        if (!isActive) return

        val operations: JSONArray = try {
            JSONArray(json)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse operations JSON: ${e.message}")
            return
        }

        // Collect ops before dispatching to main thread
        val ops = ArrayList<JSONObject>(operations.length())
        for (i in 0 until operations.length()) {
            ops.add(operations.getJSONObject(i))
        }

        mainHandler.post {
            if (!isActive) return@post

            var needsLayout = false
            for (op in ops) {
                try {
                    val opName = op.optString("op")
                    if (!needsLayout && opName in treeMutationOps) {
                        needsLayout = true
                    }
                    // Check if updateStyle changes any layout-affecting property
                    if (!needsLayout && opName == "updateStyle") {
                        val args = op.optJSONArray("args")
                        val styleObj = args?.optJSONObject(1)
                        if (styleObj != null) {
                            val keys = styleObj.keys()
                            while (keys.hasNext()) {
                                if (keys.next() in layoutAffectingStyles) {
                                    needsLayout = true
                                    break
                                }
                            }
                        }
                    }
                    handleOperation(op)
                } catch (e: Exception) {
                    Log.e(TAG, "Error handling op '${op.optString("op")}': ${e.message}")
                }
            }
            // Trigger layout when tree was mutated or layout-affecting styles changed
            if (needsLayout) {
                triggerLayout()
            }
        }
    }

    private fun handleOperation(op: JSONObject) {
        val opName = op.getString("op")
        val args = op.optJSONArray("args") ?: JSONArray()

        when (opName) {
            "create" -> handleCreate(args)
            "createText" -> handleCreateText(args)
            "setText" -> handleSetText(args)
            "setElementText" -> handleSetElementText(args)
            "updateProp" -> handleUpdateProp(args)
            "updateStyle" -> handleUpdateStyle(args)
            "appendChild" -> handleAppendChild(args)
            "insertBefore" -> handleInsertBefore(args)
            "removeChild" -> handleRemoveChild(args)
            "setRootView" -> handleSetRootView(args)
            "createTeleport" -> handleCreateTeleport(args)
            "removeTeleport" -> handleRemoveTeleport(args)
            "teleportTo" -> handleTeleportTo(args)
            "addEventListener" -> handleAddEventListener(args)
            "removeEventListener" -> handleRemoveEventListener(args)
            "invokeNativeModule" -> handleInvokeNativeModule(args)
            "invokeNativeModuleSync" -> handleInvokeNativeModuleSync(args)
            else -> Log.w(TAG, "Unknown operation: $opName")
        }
    }

    private fun handleCreate(args: JSONArray) {
        val nodeId = args.getInt(0)
        val type = args.getString(1)
        // Factories are process-wide, but Views belong to this bridge's host.
        // Preserve the Activity context for window tokens, host theming, and
        // components such as VModal and VStatusBar.
        val view = componentRegistry.createView(type, context) ?: return
        nodeViews[nodeId] = view
        nodeTypes[nodeId] = type
    }

    private fun handleCreateText(args: JSONArray) {
        // Text nodes — create a special "text node" view
        val nodeId = args.getInt(0)
        val text = args.getString(1)
        val textView = VTextNodeView(context).apply { setText(text) }
        nodeViews[nodeId] = textView
        nodeTypes[nodeId] = "__TEXT__"
    }

    private fun handleSetText(args: JSONArray) {
        val nodeId = args.getInt(0)
        val text = args.getString(1)
        val view = nodeViews[nodeId] ?: return
        (view as? VTextNodeView)?.setText(text)
        refreshTextHierarchy(nodeParents[nodeId])
    }

    private fun handleSetElementText(args: JSONArray) {
        val nodeId = args.getInt(0)
        val text = args.getString(1)
        val view = nodeViews[nodeId] ?: return
        // Delegate to the factory
        val factory = componentRegistry.factoryForType(nodeTypes[nodeId] ?: return) ?: return
        factory.updateProp(view, "text", text)
        refreshTextHierarchy(nodeParents[nodeId])
    }

    private fun handleUpdateProp(args: JSONArray) {
        val nodeId = args.getInt(0)
        val key = args.getString(1)
        val value = if (args.isNull(2)) null else args.get(2)
        val view = nodeViews[nodeId] ?: return
        val factory = componentRegistry.factoryForView(view) ?: return
        factory.updateProp(view, key, value)
    }

    private fun handleUpdateStyle(args: JSONArray) {
        val nodeId = args.getInt(0)
        val styleObj = args.optJSONObject(1) ?: return
        val view = nodeViews[nodeId] ?: return
        val factory = componentRegistry.factoryForView(view) ?: return
        val iter = styleObj.keys()
        while (iter.hasNext()) {
            val key = iter.next()
            val value = if (styleObj.isNull(key)) null else styleObj.get(key)
            factory.updateProp(view, key, value)
        }
    }

    private fun handleAppendChild(args: JSONArray) {
        val parentId = args.getInt(0)
        val childId = args.getInt(1)
        val parent = nodeViews[parentId] ?: return
        val child = nodeViews[childId] ?: return
        val insertIndex = prepareChildForInsertion(parentId, childId)
        insertChild(parent, child, insertIndex)
        refreshTextHierarchy(parentId)
    }

    private fun handleInsertBefore(args: JSONArray) {
        val parentId = args.getInt(0)
        val childId = args.getInt(1)
        val anchorId = args.getInt(2)
        // Vue can emit an insertBefore operation as part of keyed diffing even
        // when the child is already its own anchor. Detaching it in that case
        // would incorrectly move it to the end of the parent.
        if (childId == anchorId) return
        val parent = nodeViews[parentId] ?: return
        val child = nodeViews[childId] ?: return
        // The native View hierarchy is not always the logical child hierarchy:
        // RecyclerView-backed lists keep their item views in an adapter, and
        // scroll/modal factories use internal content containers. Derive the
        // insertion coordinate from nodeChildren instead of ViewGroup children.
        val insertIndex = prepareChildForInsertion(parentId, childId, anchorId)
        insertChild(parent, child, insertIndex)
        refreshTextHierarchy(parentId)
    }

    /**
     * Update the bridge's logical parent indexes and detach a child from its
     * current native owner before a move/reparent. Vue represents keyed moves as
     * insertBefore/appendChild without a preceding removeChild, so native code
     * must make the move explicit instead of attempting to add an already-parented
     * Android View.
     *
     * @return the logical index at which the child should be inserted.
     */
    private fun prepareChildForInsertion(parentId: Int, childId: Int, anchorId: Int? = null): Int {
        val child = nodeViews[childId] ?: return 0
        detachChildFromCurrentParent(childId, child)

        val siblings = nodeChildren.getOrPut(parentId) { mutableListOf() }
        // Be defensive against registries built by older bridge versions and
        // duplicate operations in a batch.
        siblings.removeAll { it == childId }

        val insertIndex = anchorId
            ?.let { siblings.indexOf(it) }
            ?.takeIf { it >= 0 }
            ?: siblings.size
        siblings.add(insertIndex, childId)
        nodeParents[childId] = parentId
        return insertIndex
    }

    /** Detach a child for a move without destroying its node registry entries. */
    private fun detachChildFromCurrentParent(childId: Int, child: View) {
        val previousParentId = nodeParents.remove(childId)
        if (previousParentId != null) {
            nodeChildren[previousParentId]?.removeAll { it == childId }
            nodeViews[previousParentId]?.let { previousParent ->
                val factory = componentRegistry.factoryForView(previousParent)
                if (factory != null) {
                    factory.removeChild(previousParent, child)
                } else {
                    (previousParent as? ViewGroup)?.removeView(child)
                }
            }
            refreshTextHierarchy(previousParentId)
        }

        // RecyclerView items and factory-owned containers are not necessarily
        // direct children of their logical parent. Remove any remaining physical
        // parent so a subsequent ViewGroup.addView cannot throw.
        (child.parent as? ViewGroup)?.removeView(child)
    }

    private fun insertChild(parent: View, child: View, index: Int) {
        val factory = componentRegistry.factoryForView(parent)
        if (factory != null) {
            factory.insertChild(parent, child, index)
            return
        }

        (parent as? ViewGroup)?.let { viewGroup ->
            viewGroup.addView(child, index.coerceIn(0, viewGroup.childCount))
        }
    }

    private fun handleRemoveChild(args: JSONArray) {
        val childId = args.getInt(0)
        val child = nodeViews[childId] ?: return
        val removingRoot = child === rootView
        val parentId = nodeParents[childId]
        val parent = parentId?.let { nodeViews[it] }

        if (parent != null) {
            val factory = componentRegistry.factoryForView(parent)
            if (factory != null) {
                factory.removeChild(parent, child)
            } else {
                (parent as? ViewGroup)?.removeView(child)
            }
        }

        // Some factories use an internal content container, and list rows may
        // still be attached to a recycled holder. Always detach the physical view
        // after updating the factory's logical state.
        (child.parent as? ViewGroup)?.removeView(child)

        // Remove child from parent's nodeChildren list
        if (parentId != null) {
            nodeChildren[parentId]?.removeAll { it == childId }
            refreshTextHierarchy(parentId)
        }

        // Recursively clean up descendants
        cleanupNode(childId)

        if (removingRoot) {
            // The modal host is a sibling of the root in hostContainer. Leaving
            // it behind after app.unmount() would create an invisible, clickable
            // full-screen view that blocks the next native screen.
            (modalContainer.parent as? ViewGroup)?.removeView(modalContainer)
            rootView = null
        }
    }

    /**
     * VText composes logical text-node children into a single TextView instead
     * of adding them to the Android view hierarchy. Rebuild the composed text
     * after child edits, moves, and removals, walking upward for nested VText.
     */
    private fun refreshTextHierarchy(startingNodeId: Int?) {
        var currentId = startingNodeId
        while (currentId != null && nodeTypes[currentId] == "VText") {
            val label = nodeViews[currentId] as? TextView ?: break
            label.text = nodeChildren[currentId]
                .orEmpty()
                .mapNotNull { childId -> (nodeViews[childId] as? TextView)?.text?.toString() }
                .joinToString(separator = "")
            currentId = nodeParents[currentId]
        }
    }

    private fun cleanupNode(nodeId: Int) {
        // Recursively clean up children using the reverse index (O(subtree) not O(n))
        nodeChildren[nodeId]?.toList()?.forEach { cleanupNode(it) }
        nodeParents.remove(nodeId)
        // O(k) event cleanup via reverse index instead of O(n) full scan
        eventKeysPerNode.remove(nodeId)?.forEach { key ->
            eventHandlers.remove(key)
        }
        // Call destroyView on the factory to clean up factory-level state (e.g. VListFactory maps)
        val view = nodeViews[nodeId]
        if (view != null) {
            val factory = componentRegistry.factoryForView(view)
            factory?.destroyView(view)
        }
        nodeViews.remove(nodeId)
        nodeTypes.remove(nodeId)
        nodeChildren.remove(nodeId)
    }

    private fun handleSetRootView(args: JSONArray) {
        val nodeId = args.getInt(0)
        val view = nodeViews[nodeId] ?: return
        rootView = view

        val container = hostContainer ?: return
        container.removeAllViews()
        container.addView(
            view,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        // Add modal container for teleport
        container.addView(
            modalContainer,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
    }

    // -- Teleport handlers --

    private fun handleCreateTeleport(args: JSONArray) {
        val parentId = args.getInt(0)
        val startId = args.getInt(1)
        val endId = args.getInt(2)

        val parentView = nodeViews[parentId] ?: run {
            Log.w(TAG, "Parent view not found for teleport (id: $parentId)")
            return
        }

        // Store teleport marker IDs
        teleportMarkers[parentId] = Pair(startId, endId)

        // Create container for teleported content
        val container = FrameLayout(context).apply {
            id = View.generateViewId()
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            isClickable = true
            isFocusable = false
        }

        if (parentView is ViewGroup) {
            parentView.addView(container)
            teleportContainers[parentId] = container
        }

        Log.d(TAG, "Created teleport container for parent $parentId")
    }

    private fun handleRemoveTeleport(args: JSONArray) {
        val parentId = args.getInt(0)

        // Remove teleport container
        teleportContainers.remove(parentId)?.let { container ->
            mainHandler.post {
                (container.parent as? ViewGroup)?.removeView(container)
            }
        }

        // Clean up markers
        teleportMarkers.remove(parentId)

        Log.d(TAG, "Removed teleport container for parent $parentId")
    }

    private fun handleTeleportTo(args: JSONArray) {
        val target = args.getString(0)
        val nodeId = args.getInt(1)

        val targetView = getTeleportTarget(target) ?: run {
            Log.w(TAG, "Teleport target '$target' not found")
            return
        }

        val childView = nodeViews[nodeId] ?: run {
            Log.w(TAG, "Node view not found for teleport (id: $nodeId)")
            return
        }

        // Move view to teleport target
        mainHandler.post {
            (childView.parent as? ViewGroup)?.removeView(childView)
            targetView.addView(childView)
            childView.requestLayout()
        }

        Log.d(TAG, "Teleported node $nodeId to target '$target'")
    }

    private fun getTeleportTarget(target: String): ViewGroup? {
        return when (target) {
            "root" -> rootView as? ViewGroup
            "modal" -> {
                // Ensure modal container is added to root if not already
                if (modalContainer.parent == null && rootView != null) {
                    (rootView as? ViewGroup)?.addView(modalContainer)
                }
                modalContainer
            }
            else -> null
        }
    }

    private fun handleAddEventListener(args: JSONArray) {
        val nodeId = args.getInt(0)
        val eventName = args.getString(1)
        val view = nodeViews[nodeId] ?: return
        val factory = componentRegistry.factoryForView(view) ?: return

        val key = "$nodeId:$eventName"

        // Remove old handler first to prevent duplicate event firing (e.g. recycled node IDs)
        if (eventHandlers.containsKey(key)) {
            factory.removeEventListener(view, eventName)
            eventHandlers.remove(key)
        }

        val handler: (Any?) -> Unit = { payload ->
            val payloadJson = when (payload) {
                null -> "null"
                is Map<*, *> -> JSONObject(payload).toString()
                is String -> JSONObject.quote(payload)
                else -> payload.toString()
            }
            onFireEvent?.invoke(nodeId, eventName, payloadJson)
        }

        factory.addEventListener(view, eventName, handler)
        eventHandlers[key] = handler
        eventKeysPerNode.getOrPut(nodeId) { mutableSetOf() }.add(key)
    }

    private fun handleRemoveEventListener(args: JSONArray) {
        val nodeId = args.getInt(0)
        val eventName = args.getString(1)
        val view = nodeViews[nodeId] ?: return
        val factory = componentRegistry.factoryForView(view) ?: return
        factory.removeEventListener(view, eventName)

        val key = "$nodeId:$eventName"
        eventHandlers.remove(key)
        eventKeysPerNode[nodeId]?.remove(key)
    }

    private fun handleInvokeNativeModule(args: JSONArray) {
        val moduleName = args.getString(0)
        val methodName = args.getString(1)
        val moduleArgs = buildArgsList(args.optJSONArray(2))
        val callbackId = args.optInt(3, -1)
        val originatingGeneration = nativeCallbackGeneration

        NativeModuleRegistry.getInstance(context).invoke(
            moduleName, methodName, moduleArgs, this
        ) { result, error ->
            if (callbackId >= 0) {
                val resultJson = when (result) {
                    null -> "null"
                    is Map<*, *> -> JSONObject(result).toString()
                    is List<*> -> JSONArray(result).toString()
                    is String -> JSONObject.quote(result)
                    is Boolean -> result.toString()
                    is Number -> result.toString()
                    else -> result.toString()
                }
                val errorJson = if (error != null) JSONObject.quote(error) else "null"
                mainHandler.post {
                    if (!isActive || nativeCallbackGeneration != originatingGeneration) {
                        return@post
                    }
                    resolveCallbackInJs(callbackId, resultJson, errorJson)
                }
            }
        }
    }

    private fun handleInvokeNativeModuleSync(args: JSONArray) {
        val moduleName = args.getString(0)
        val methodName = args.getString(1)
        val moduleArgs = buildArgsList(args.optJSONArray(2))
        try {
            NativeModuleRegistry.getInstance(context).invokeSync(moduleName, methodName, moduleArgs, this)
        } catch (e: Exception) {
            Log.e(TAG, "Error in sync module invoke $moduleName.$methodName: ${e.message}")
        }
    }

    private fun resolveCallbackInJs(callbackId: Int, resultJson: String, errorJson: String) {
        onFireEvent?.invoke(-1, "__callback__",
            "{\"callbackId\":$callbackId,\"result\":$resultJson,\"error\":$errorJson}")
    }

    private fun buildArgsList(arr: JSONArray?): List<Any?> {
        arr ?: return emptyList()
        return (0 until arr.length()).map { index ->
            jsonValueToKotlin(arr.opt(index))
        }
    }

    /**
     * org.json containers are an implementation detail of the batched bridge.
     * Native module APIs consume ordinary Kotlin collections, so recursively
     * normalize nested values before crossing the module boundary.
     */
    private fun jsonValueToKotlin(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONArray -> (0 until value.length()).map { index ->
            jsonValueToKotlin(value.opt(index))
        }
        is JSONObject -> buildMap {
            val keys = value.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                put(key, jsonValueToKotlin(value.opt(key)))
            }
        }
        else -> value
    }

    // -------------------------------------------------------------------------
    // Registry management
    // -------------------------------------------------------------------------

    /** Clear all registries. Called during hot reload after JS teardown. Must run on main thread. */
    fun clearAllRegistries() {
        nativeCallbackGeneration += 1

        teleportContainers.values.forEach { container ->
            (container.parent as? ViewGroup)?.removeView(container)
        }
        teleportContainers.clear()
        teleportMarkers.clear()

        // Destroy all views via their factories before clearing maps
        for ((_, view) in nodeViews) {
            val factory = componentRegistry.factoryForView(view)
            factory?.destroyView(view)
        }
        nodeViews.clear()
        nodeTypes.clear()
        eventHandlers.clear()
        eventKeysPerNode.clear()
        nodeParents.clear()
        nodeChildren.clear()
        (modalContainer.parent as? ViewGroup)?.removeView(modalContainer)
        rootView = null
    }

    /**
     * Permanently detach this bridge from its Activity host.
     *
     * A JS runtime owns exactly one NativeBridge, so Activity teardown can
     * invalidate queued UI batches and release every factory-owned resource
     * without affecting a replacement Activity's bridge.
     */
    fun destroyHost() {
        isActive = false
        mainHandler.removeCallbacksAndMessages(null)
        clearAllRegistries()
        hostContainer?.removeAllViews()
        hostContainer = null
        onFireEvent = null
        onDispatchGlobalEvent = null
    }

    // -------------------------------------------------------------------------
    // Layout
    // -------------------------------------------------------------------------

    fun triggerLayout() {
        rootView?.let { root ->
            root.requestLayout()
        }
    }

    // -------------------------------------------------------------------------
    // Events: Native to JS
    // -------------------------------------------------------------------------

    /** Fire an event from a native view to the JS side. */
    fun fireEvent(nodeId: Int, eventName: String, payload: Map<String, Any?>? = null) {
        val payloadJson = if (payload != null) JSONObject(payload).toString() else "null"
        onFireEvent?.invoke(nodeId, eventName, payloadJson)
    }

    /** Dispatch a global push event to JS. Called from modules. */
    fun dispatchGlobalEvent(eventName: String, payload: Map<String, Any> = emptyMap()) {
        val payloadJson = JSONObject(payload).toString()
        onDispatchGlobalEvent?.invoke(eventName, payloadJson)
    }
}
