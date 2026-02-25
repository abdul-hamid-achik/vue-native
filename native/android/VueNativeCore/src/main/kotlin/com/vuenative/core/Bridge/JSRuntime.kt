package com.vuenative.core

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import com.eclipsesource.v8.JavaVoidCallback
import com.eclipsesource.v8.V8

/**
 * Core JavaScript runtime. Wraps J2V8's V8 engine on a dedicated HandlerThread.
 *
 * Thread safety contract:
 * - All V8 access happens exclusively on jsThread via jsHandler
 * - Never pass J2V8 objects (V8Array, V8Object) across threads
 * - All View operations happen on main thread via mainHandler
 */
class JSRuntime(private val context: Context) {

    companion object {
        private const val TAG = "VueNative-JSRuntime"
    }

    /** Dedicated JS thread. All V8 operations run here. */
    private val jsThread = HandlerThread("VueNative-JS").apply { start() }

    /** Handler for posting work to the JS thread. */
    val jsHandler = Handler(jsThread.looper)

    /** Handler for posting work to the main (UI) thread. */
    private val mainHandler = Handler(Looper.getMainLooper())

    /** V8 runtime instance. Only access from jsThread. */
    private var v8: V8? = null

    /** Whether the runtime has been initialized. */
    private var isInitialized = false

    /** The NativeBridge instance — manages view registry and operations. */
    val bridge = NativeBridge(context)

    /** Startup time in milliseconds for performance.now(). */
    val startTimeMs: Long = System.currentTimeMillis()

    init {
        // Wire bridge callbacks
        bridge.onFireEvent = { nodeId, eventName, payloadJson ->
            // Called on main thread — dispatch to JS
            jsHandler.post {
                try {
                    if (nodeId == -1 && eventName == "__callback__") {
                        // Native module async callback — route to __VN_resolveCallback
                        v8?.executeVoidScript(
                            "if(typeof __VN_resolveCallback==='function'){" +
                            "var _d=$payloadJson;" +
                            "__VN_resolveCallback(_d.callbackId,_d.result,_d.error);}"
                        )
                    } else {
                        v8?.executeVoidScript(
                            "if(typeof __VN_handleEvent==='function')" +
                            "__VN_handleEvent($nodeId,${encodeJs(eventName)},$payloadJson)"
                        )
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error dispatching event $eventName to JS", e)
                }
            }
        }
        bridge.onDispatchGlobalEvent = { eventName, payloadJson ->
            jsHandler.post {
                try {
                    v8?.executeVoidScript(
                        "if(typeof __VN_handleGlobalEvent==='function')" +
                        "__VN_handleGlobalEvent(${encodeJs(eventName)},${encodeJs(payloadJson)})"
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error dispatching global event $eventName", e)
                }
            }
        }
    }

    /** Initialize the V8 runtime on the JS thread. Calls completion when ready. */
    fun initialize(completion: (() -> Unit)? = null) {
        jsHandler.post {
            if (isInitialized) {
                mainHandler.post { completion?.invoke() }
                return@post
            }
            try {
                v8 = V8.createV8Runtime()
                JSPolyfills.register(this)
                // Register __VN_flushOperations — JS calls this to send batched ops to native
                v8?.registerJavaMethod(JavaVoidCallback { _, params ->
                    try {
                        val json = if (params.length() > 0) params.getString(0) else "[]"
                        bridge.processOperations(json)
                    } finally {
                        params.close()
                    }
                }, "__VN_flushOperations")

                // Register __VN_handleError — JS calls this to report errors to native
                v8?.registerJavaMethod(JavaVoidCallback { _, params ->
                    try {
                        val errorJson = if (params.length() > 0) params.getString(0) else "{}"
                        Log.e(TAG, "[VueNative Error] $errorJson")
                    } finally {
                        params.close()
                    }
                }, "__VN_handleError")

                isInitialized = true
                Log.d(TAG, "V8 runtime initialized")
                mainHandler.post { completion?.invoke() }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize V8 runtime", e)
            }
        }
    }

    /** Load and execute a JavaScript bundle. Must be called after initialize().
     *  @param onComplete Optional callback invoked on main thread: (success, errorMessage). */
    fun loadBundle(bundleCode: String, onComplete: ((Boolean, String?) -> Unit)? = null) {
        jsHandler.post {
            try {
                v8?.executeVoidScript(bundleCode)
                Log.d(TAG, "Bundle loaded successfully")
                mainHandler.post { onComplete?.invoke(true, null) }
            } catch (e: Exception) {
                Log.e(TAG, "Error loading bundle", e)
                val msg = e.message ?: "Unknown error"
                mainHandler.post {
                    ErrorOverlayView.show(context, msg)
                    onComplete?.invoke(false, msg)
                }
            }
        }
    }

    /** Post work to the JS thread. */
    fun runOnJsThread(block: () -> Unit) {
        jsHandler.post(block)
    }

    /** Post work to the main (UI) thread. */
    fun runOnMainThread(block: () -> Unit) {
        mainHandler.post(block)
    }

    /** Execute a void script on the JS thread. Safe to call from any thread. */
    fun executeVoidScript(script: String) {
        jsHandler.post {
            try {
                v8?.executeVoidScript(script)
            } catch (e: Exception) {
                Log.e(TAG, "Script error: ${e.message}")
            }
        }
    }

    /** Register a void Java method as a global JS function. Call from JS thread only. */
    fun registerVoidCallback(name: String, callback: (Array<Any?>) -> Unit) {
        jsHandler.post {
            v8?.registerJavaMethod(JavaVoidCallback { _, params ->
                try {
                    val args = Array<Any?>(params.length()) { i ->
                        when {
                            params.getType(i) == 1 -> params.getInteger(i) // INT
                            params.getType(i) == 2 -> params.getDouble(i) // DOUBLE
                            params.getType(i) == 3 -> params.getBoolean(i) // BOOLEAN
                            params.getType(i) == 4 -> params.getString(i) // STRING
                            else -> null
                        }
                    }
                    callback(args)
                } finally {
                    params.close()
                }
            }, name)
        }
    }

    /** Access raw V8 instance — only call from JS thread! */
    fun withV8(block: (V8) -> Unit) {
        jsHandler.post {
            v8?.let(block)
        }
    }

    /** Get raw V8 — ONLY call from JS thread. Returns null if not initialized. */
    fun v8(): V8? = v8

    /** Release the V8 runtime. */
    fun release() {
        jsHandler.post {
            v8?.release(true)
            v8 = null
            isInitialized = false
        }
        jsThread.quitSafely()
    }

    private fun encodeJs(value: String): String =
        "\"${value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")}\""
}
