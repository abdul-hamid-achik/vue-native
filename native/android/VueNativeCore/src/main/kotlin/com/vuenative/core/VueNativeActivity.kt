package com.vuenative.core

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONObject

/**
 * Base Activity class for all Vue Native apps.
 *
 * Subclass this and override getBundleAssetPath() to provide the JS bundle.
 * Optionally override getDevServerUrl() to enable hot reload.
 *
 * Example:
 * ```kotlin
 * class MainActivity : VueNativeActivity() {
 *     override fun getBundleAssetPath() = "vue-native-bundle.js"
 * }
 * ```
 */
abstract class VueNativeActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "VueNativeActivity"
    }

    /** Return the asset path for the JS bundle (e.g., "vue-native-bundle.js"). */
    abstract fun getBundleAssetPath(): String

    /** Return WebSocket URL of the Vite dev server for hot reload, or null to disable. */
    open fun getDevServerUrl(): String? = null

    protected lateinit var runtime: JSRuntime
    private lateinit var rootContainer: FrameLayout
    private var hotReloadManager: HotReloadManager? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Create the root container
        rootContainer = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        setContentView(rootContainer)

        // Make the app draw behind system bars for edge-to-edge
        window.statusBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }

        // Initialize runtime and bridge
        runtime = JSRuntime(this)
        runtime.bridge.hostContainer = rootContainer

        // Register native modules
        NativeModuleRegistry.getInstance(this).registerDefaults(runtime.bridge)

        // Wire up resolveCallback for async module calls
        wireCallbackResolution()

        // Initialize JS engine then load bundle
        runtime.initialize {
            loadBundle()
        }
    }

    private fun wireCallbackResolution() {
        runtime.bridge.onFireEvent = { nodeId, eventName, payloadJson ->
            if (nodeId == -1 && eventName == "__callback__") {
                try {
                    val obj = JSONObject(payloadJson)
                    val cbId = obj.getInt("callbackId")
                    val result = if (obj.isNull("result")) "null" else obj.get("result").toString()
                    val error  = if (obj.isNull("error"))  "null" else "\"${obj.getString("error").replace("\"","\\\"")}\""
                    runtime.executeVoidScript(
                        "if(typeof __VN_resolveCallback==='function')" +
                        "__VN_resolveCallback($cbId,$result,$error)"
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error resolving callback: ${e.message}")
                }
            } else {
                runtime.executeVoidScript(
                    "if(typeof __VN_handleEvent==='function')" +
                    "__VN_handleEvent($nodeId,\"$eventName\",$payloadJson)"
                )
            }
        }
        runtime.bridge.onDispatchGlobalEvent = { eventName, payloadJson ->
            runtime.executeVoidScript(
                "if(typeof __VN_handleGlobalEvent==='function')" +
                "__VN_handleGlobalEvent(\"$eventName\",${JSONObject.quote(payloadJson)})"
            )
        }
    }

    private fun loadBundle() {
        val devUrl = getDevServerUrl()
        if (devUrl != null) {
            val bundleHttpUrl = devUrl.replace("ws://", "http://").replace("wss://", "https://")
                .trimEnd('/') + "/${getBundleAssetPath()}"

            hotReloadManager = HotReloadManager(runtime) { bundleCode ->
                runOnUiThread {
                    runtime.bridge.nodeViews.clear()
                    runtime.bridge.nodeTypes.clear()
                    runtime.bridge.eventHandlers.clear()
                    runtime.bridge.nodeParents.clear()
                    runtime.bridge.rootView = null
                    rootContainer.removeAllViews()
                }
                runtime.loadBundle(bundleCode)
            }
            hotReloadManager?.connect(devUrl, bundleHttpUrl)

            // Also load from assets as fallback
            loadFromAssets()
        } else {
            loadFromAssets()
        }
    }

    private fun loadFromAssets() {
        try {
            val bundleCode = assets.open(getBundleAssetPath()).bufferedReader().readText()
            runtime.loadBundle(bundleCode)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load bundle from assets: ${e.message}")
            ErrorOverlayView.show(this, "Failed to load bundle: ${e.message}")
        }
    }

    override fun onDestroy() {
        hotReloadManager?.disconnect()
        runtime.release()
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        runtime.executeVoidScript(
            "if(typeof __VN_handleGlobalEvent==='function')" +
            "__VN_handleGlobalEvent('android:back','{}')"
        )
        super.onBackPressed()
    }
}
