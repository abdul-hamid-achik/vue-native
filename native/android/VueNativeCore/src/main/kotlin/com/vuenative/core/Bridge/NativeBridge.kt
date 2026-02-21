package com.vuenative.core

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import org.json.JSONArray
import org.json.JSONObject

/**
 * Receives batched JS operations, dispatches them to the native view system,
 * and provides event firing back to JS.
 */
class NativeBridge(private val context: Context) {

    companion object {
        private const val TAG = "VueNative-Bridge"
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    // -- View registry --
    /** Maps node IDs to native Views. Accessed only on main thread. */
    val nodeViews = mutableMapOf<Int, View>()

    /** Maps node IDs to component type strings. Accessed only on main thread. */
    val nodeTypes = mutableMapOf<Int, String>()

    /** Maps "nodeId:eventName" to handler. Accessed only on main thread. */
    val eventHandlers = mutableMapOf<String, (Any?) -> Unit>()

    /** Maps child nodeId to parent nodeId. Accessed only on main thread. */
    val nodeParents = mutableMapOf<Int, Int>()

    /** The root view of the tree — set when __ROOT__ node is made the root view. */
    var rootView: View? = null

    /** The container view from the host Activity — where the root view is attached. */
    var hostContainer: ViewGroup? = null

    /** Called when native fires an event to JS (nodeId, eventName, payloadJson). */
    var onFireEvent: ((nodeId: Int, eventName: String, payloadJson: String) -> Unit)? = null

    /** Called when a module dispatches a global event to JS (eventName, payloadJson). */
    var onDispatchGlobalEvent: ((eventName: String, payloadJson: String) -> Unit)? = null

    private val componentRegistry: ComponentRegistry by lazy { ComponentRegistry.getInstance(context) }

    // -------------------------------------------------------------------------
    // Operation processing — called from JS thread
    // -------------------------------------------------------------------------

    /** Called from JS thread via __VN_flushOperations. Parses JSON and dispatches to main. */
    fun processOperations(json: String) {
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
            for (op in ops) {
                try {
                    handleOperation(op)
                } catch (e: Exception) {
                    Log.e(TAG, "Error handling op '${op.optString("op")}': ${e.message}")
                }
            }
            triggerLayout()
        }
    }

    private fun handleOperation(op: JSONObject) {
        val opName = op.getString("op")
        val args = op.optJSONArray("args") ?: JSONArray()

        when (opName) {
            "create"               -> handleCreate(args)
            "createText"           -> handleCreateText(args)
            "setText"              -> handleSetText(args)
            "setElementText"       -> handleSetElementText(args)
            "updateProp"           -> handleUpdateProp(args)
            "updateStyle"          -> handleUpdateStyle(args)
            "appendChild"          -> handleAppendChild(args)
            "insertBefore"         -> handleInsertBefore(args)
            "removeChild"          -> handleRemoveChild(args)
            "setRootView"          -> handleSetRootView(args)
            "addEventListener"     -> handleAddEventListener(args)
            "removeEventListener"  -> handleRemoveEventListener(args)
            "invokeNativeModule"   -> handleInvokeNativeModule(args)
            "invokeNativeModuleSync" -> handleInvokeNativeModuleSync(args)
            else -> Log.w(TAG, "Unknown operation: $opName")
        }
    }

    private fun handleCreate(args: JSONArray) {
        val nodeId = args.getInt(0)
        val type = args.getString(1)
        val view = componentRegistry.createView(type) ?: return
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
    }

    private fun handleSetElementText(args: JSONArray) {
        val nodeId = args.getInt(0)
        val text = args.getString(1)
        val view = nodeViews[nodeId] ?: return
        // Delegate to the factory
        val factory = componentRegistry.factoryForType(nodeTypes[nodeId] ?: return) ?: return
        factory.updateProp(view, "text", text)
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
        nodeParents[childId] = parentId

        val factory = componentRegistry.factoryForView(parent)
        if (factory != null) {
            val idx = (parent as? ViewGroup)?.childCount ?: 0
            factory.insertChild(parent, child, idx)
        } else {
            (parent as? ViewGroup)?.addView(child)
        }
    }

    private fun handleInsertBefore(args: JSONArray) {
        val parentId = args.getInt(0)
        val childId = args.getInt(1)
        val anchorId = args.getInt(2)
        val parent = nodeViews[parentId] ?: return
        val child = nodeViews[childId] ?: return
        val anchor = nodeViews[anchorId] ?: return
        nodeParents[childId] = parentId

        val vg = parent as? ViewGroup ?: return
        val anchorIdx = vg.indexOfChild(anchor)
        val insertIdx = if (anchorIdx < 0) vg.childCount else anchorIdx

        val factory = componentRegistry.factoryForView(parent)
        if (factory != null) {
            factory.insertChild(parent, child, insertIdx)
        } else {
            vg.addView(child, insertIdx)
        }
    }

    private fun handleRemoveChild(args: JSONArray) {
        val childId = args.getInt(0)
        val child = nodeViews[childId] ?: return
        val parentId = nodeParents[childId]
        val parent = parentId?.let { nodeViews[it] }

        if (parent != null) {
            val factory = componentRegistry.factoryForView(parent)
            if (factory != null) {
                factory.removeChild(parent, child)
            } else {
                (parent as? ViewGroup)?.removeView(child)
            }
        } else {
            (child.parent as? ViewGroup)?.removeView(child)
        }

        // Recursively clean up descendants
        cleanupNode(childId)
    }

    private fun cleanupNode(nodeId: Int) {
        nodeParents.remove(nodeId)
        eventHandlers.entries.removeAll { it.key.startsWith("$nodeId:") }
        val view = nodeViews.remove(nodeId) ?: return
        // Clean up children
        (view as? ViewGroup)?.let { vg ->
            val childIds = nodeViews.entries.filter { (_, v) -> v.parent == vg }.map { it.key }
            childIds.forEach { cleanupNode(it) }
        }
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
    }

    private fun handleAddEventListener(args: JSONArray) {
        val nodeId = args.getInt(0)
        val eventName = args.getString(1)
        val view = nodeViews[nodeId] ?: return
        val factory = componentRegistry.factoryForView(view) ?: return
        factory.addEventListener(view, eventName) { payload ->
            val payloadJson = when (payload) {
                null -> "null"
                is Map<*, *> -> JSONObject(payload).toString()
                is String -> "\"${payload.replace("\"", "\\\"")}\""
                else -> payload.toString()
            }
            onFireEvent?.invoke(nodeId, eventName, payloadJson)
        }
    }

    private fun handleRemoveEventListener(args: JSONArray) {
        val nodeId = args.getInt(0)
        val eventName = args.getString(1)
        val view = nodeViews[nodeId] ?: return
        val factory = componentRegistry.factoryForView(view) ?: return
        factory.removeEventListener(view, eventName)
    }

    private fun handleInvokeNativeModule(args: JSONArray) {
        val moduleName = args.getString(0)
        val methodName = args.getString(1)
        val moduleArgs = buildArgsList(args.optJSONArray(2))
        val callbackId = args.optInt(3, -1)

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
                resolveCallbackInJs(callbackId, resultJson, errorJson)
            }
        }
    }

    private fun handleInvokeNativeModuleSync(args: JSONArray) {
        val moduleName = args.getString(0)
        val methodName = args.getString(1)
        val moduleArgs = buildArgsList(args.optJSONArray(2))
        NativeModuleRegistry.getInstance(context).invokeSync(moduleName, methodName, moduleArgs, this)
    }

    private fun resolveCallbackInJs(callbackId: Int, resultJson: String, errorJson: String) {
        onFireEvent?.invoke(-1, "__callback__",
            "{\"callbackId\":$callbackId,\"result\":$resultJson,\"error\":$errorJson}")
    }

    private fun buildArgsList(arr: JSONArray?): List<Any?> {
        arr ?: return emptyList()
        return (0 until arr.length()).map { i ->
            if (arr.isNull(i)) null else arr.get(i)
        }
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
