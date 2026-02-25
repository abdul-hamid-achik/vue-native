package com.vuenative.core

import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity

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

        // Provide Activity reference for modules that need it (e.g. PermissionsModule)
        PermissionsModule.setActivity(this)

        // Capture launch intent deep link URL for the LinkingModule
        intent?.data?.toString()?.let { url ->
            val linkingModule = NativeModuleRegistry.getInstance(this)
                .getModule("Linking") as? LinkingModule
            linkingModule?.initialURL = url
        }

        // Initialize JS engine then load bundle
        runtime.initialize {
            loadBundle()
        }
    }

    private fun loadBundle() {
        val devUrl = getDevServerUrl()
        if (devUrl != null) {
            val bundleHttpUrl = devUrl.replace("ws://", "http://").replace("wss://", "https://")
                .trimEnd('/') + "/${getBundleAssetPath()}"

            hotReloadManager = HotReloadManager(runtime) { bundleCode ->
                // Properly sequence reload steps to avoid races between threads.
                // Step 1: Teardown old app and reset polyfills on JS thread
                runtime.runOnJsThread {
                    try {
                        runtime.v8()?.executeVoidScript(
                            "if(typeof __VN_teardown==='function') __VN_teardown()"
                        )
                    } catch (e: Exception) {
                        Log.w(TAG, "Error calling __VN_teardown: ${e.message}")
                    }
                    // Reset polyfill state (timers, RAF) on JS thread where they are used
                    JSPolyfills.reset()

                    // Step 2: Clear native registries on main thread, THEN load bundle
                    runtime.runOnMainThread {
                        runtime.bridge.clearAllRegistries()
                        rootContainer.removeAllViews()

                        // Step 3: Load new bundle on JS thread (after registries are cleared)
                        runtime.loadBundle(bundleCode) { success, errorMsg ->
                            if (!success) {
                                Log.e(TAG, "Hot reload bundle failed: $errorMsg")
                            }
                        }
                    }
                }
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

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        intent?.data?.toString()?.let { url ->
            runtime.bridge.dispatchGlobalEvent("url", mapOf("url" to url))
        }
    }

    override fun onDestroy() {
        PermissionsModule.setActivity(null)
        hotReloadManager?.disconnect()
        runtime.release()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        PermissionsModule.onPermissionsResult(requestCode, permissions, grantResults)
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        // Let JS handle back navigation — do not call super.onBackPressed()
        runtime.executeVoidScript(
            "if(typeof __VN_handleGlobalEvent==='function')" +
            "__VN_handleGlobalEvent('hardware:backPress','{}')"
        )
    }
}
