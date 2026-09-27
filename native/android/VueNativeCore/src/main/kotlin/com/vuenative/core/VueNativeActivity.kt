package com.vuenative.core

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/**
 * Base Activity class for all Vue Native apps.
 *
 * Subclass this and override [getBundleAssetPath] to provide the JS bundle.
 * Optionally override [getDevServerUrl] to enable hot reload in debug builds.
 *
 * ```kotlin
 * class MainActivity : VueNativeActivity() {
 *     override fun getBundleAssetPath() = "vue-native-bundle.js"
 * }
 * ```
 *
 * ## Manifest requirements for a hand-written host
 *
 * The CLI scaffold (`vue-native create <name>`) writes these for you. If you
 * declare the Activity by hand you must match them:
 *
 * ```xml
 * <activity
 *     android:name=".MainActivity"
 *     android:exported="true"
 *     android:configChanges="orientation|screenSize|screenLayout|keyboardHidden|keyboard|locale|layoutDirection|fontScale|uiMode|density"
 *     android:windowSoftInputMode="adjustResize">
 *     <intent-filter>
 *         <action android:name="android.intent.action.MAIN" />
 *         <category android:name="android.intent.category.LAUNCHER" />
 *     </intent-filter>
 * </activity>
 * ```
 *
 * **`android:configChanges` is not optional.** Without it Android destroys and
 * recreates the Activity on rotation, dark-mode switch, locale change, keyboard
 * attach and font-scale change — and because the Vue app lives in a V8 isolate
 * owned by this Activity, *every bit of JS state is wiped*: component state,
 * Pinia/Vuex stores, in-flight promises and the whole navigation stack. The app
 * visibly restarts at its root route. Declaring the list above makes Android
 * deliver [onConfigurationChanged] instead, which keeps the same runtime and
 * re-emits `dimensionsChange` / `colorScheme:change` to your composables.
 *
 * **`android:windowSoftInputMode="adjustResize"`** is what lets the IME insets
 * applied in [onCreate] shrink the content instead of covering the focused
 * input. This Activity draws edge-to-edge (`setDecorFitsSystemWindows(false)` on
 * API 30+), which makes plain `adjustResize` a no-op on its own — the Activity
 * compensates by padding the root container with the IME bottom inset, and that
 * path relies on the soft-input mode being `adjustResize` rather than
 * `adjustNothing`/`adjustPan`. `VKeyboardAvoiding` also depends on it.
 *
 * Hosts that need permissions for camera, microphone, location, contacts,
 * calendar, notifications, media or Bluetooth must declare them in their own
 * manifest — VueNativeCore no longer merges them in. See the opt-in snippet in
 * `VueNativeCore/src/main/AndroidManifest.xml`.
 */
abstract class VueNativeActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "VueNativeActivity"
    }

    /** Return the asset path for the JS bundle (e.g., "vue-native-bundle.js"). */
    abstract fun getBundleAssetPath(): String

    /**
     * Read the embedded JS bundle. Production hosts load [getBundleAssetPath]
     * from APK assets. Tests may override this to supply the committed
     * app-shell fixture without packaging an asset.
     */
    protected open fun readEmbeddedBundle(): String =
        assets.open(getBundleAssetPath()).bufferedReader().readText()

    /**
     * Return the WebSocket URL of the Vite dev server for hot reload, or null to
     * disable it.
     *
     * Hot reload opens a **plaintext** `ws://` socket and evaluates whatever
     * JavaScript arrives on it with full native-module privileges, so it is only
     * ever honoured when *both* of the following hold:
     *
     * 1. this build is debuggable (`ApplicationInfo.FLAG_DEBUGGABLE`), and
     * 2. the URL points at a loopback / private-network address (see
     *    [DevServerPolicy]).
     *
     * A release APK that returns a URL here logs an error and loads the embedded
     * (or OTA) bundle instead. Put the override in `src/debug` so a release
     * variant cannot even be compiled with it — that is what the repo's own
     * example app does.
     */
    open fun getDevServerUrl(): String? = null

    /**
     * Create application-specific native modules for one JavaScript world.
     *
     * This factory runs at startup and for every accepted hot reload. Return new
     * instances on every call. Modules are registered after built-in and generated
     * modules, so an application module with the same name intentionally replaces
     * the default implementation.
     */
    protected open fun createNativeModules(): List<NativeModule> = emptyList()

    /**
     * Escape hatch: register a custom component factory under [name] so Vue
     * `create` operations for that type instantiate it. Backed by the process-wide
     * [ComponentRegistry], so the registration is visible to every bridge in the
     * process. A factory registered with an existing type name replaces it.
     *
     * ```kotlin
     * class MainActivity : VueNativeActivity() {
     *     override fun onCreate(savedInstanceState: Bundle?) {
     *         registerComponent("MyChart", MyChartFactory())
     *         super.onCreate(savedInstanceState)
     *     }
     * }
     * ```
     */
    fun registerComponent(name: String, factory: NativeComponentFactory) {
        ComponentRegistry.getInstance(this).register(name, factory)
    }

    protected lateinit var runtime: JSRuntime
    private lateinit var rootContainer: FrameLayout
    private var hotReloadManager: HotReloadManager? = null

    /**
     * Routes hardware/gesture back through the JS `hardware:backPress` event that
     * `useBackHandler` subscribes to.
     *
     * Registered with [OnBackPressedDispatcher] rather than by overriding the
     * deprecated `Activity.onBackPressed`: the dispatcher is what AndroidX and
     * the predictive-back gesture actually invoke, and it keeps the existing
     * contract intact — JS still gets the event first and [performDefaultBackAction]
     * still runs only when JS did not handle it.
     */
    private val vueNativeBackCallback = object : OnBackPressedCallback(true) {
        override fun handleOnBackPressed() {
            if (!::runtime.isInitialized) {
                performDefaultBackAction()
                return
            }
            runtime.dispatchGlobalEvent("hardware:backPress", "{}") { handled ->
                if (!handled) {
                    performDefaultBackAction()
                }
            }
        }
    }

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

        // Drawing edge-to-edge makes android:windowSoftInputMode="adjustResize" a
        // no-op on API 30+ (nothing resizes the window any more), which left the
        // soft keyboard covering the focused input. VKeyboardAvoidingFactory has
        // always relied on adjustResize for this, so pad the root container by
        // the IME bottom inset ourselves. Insets are returned unconsumed so
        // children (and any host-provided inset handling) still see them.
        ViewCompat.setOnApplyWindowInsetsListener(rootContainer) { view, insets ->
            val imeBottom = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
            if (view.paddingBottom != imeBottom) {
                view.setPadding(view.paddingLeft, view.paddingTop, view.paddingRight, imeBottom)
            }
            insets
        }
        ViewCompat.requestApplyInsets(rootContainer)

        // Initialize runtime and bridge
        runtime = JSRuntime(this)
        runtime.bridge.hostContainer = rootContainer

        // Register built-in/generated modules first, then application modules.
        registerNativeModules()

        // Provide Activity reference for modules that need it (e.g. PermissionsModule)
        PermissionsModule.setActivity(this)
        BackHandlerModule.setActivity(this)
        ImagePickerModule.setActivity(this)
        CameraModule.setActivity(this)

        // Capture launch intent deep link URL for the LinkingModule
        intent?.data?.toString()?.let { url ->
            val linkingModule = NativeModuleRegistry.getInstance(this)
                .getModule("Linking") as? LinkingModule
            linkingModule?.initialURL = url
        }

        onBackPressedDispatcher.addCallback(this, vueNativeBackCallback)

        // Initialize JS engine then load bundle
        runtime.initialize {
            loadBundle()
        }
    }

    private fun loadBundle() {
        val devUrl = resolveDevServerUrl()
        if (devUrl != null) {
            val manager = HotReloadManager { bundleCode ->
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

                    // Step 2: Replace native state on main, THEN load the bundle.
                    // JS teardown queues async module cleanup and immediately
                    // resets its pending bridge batch, so the native module
                    // registry must synchronously destroy the old snapshot.
                    runtime.runOnMainThread {
                        if (isFinishing || isDestroyed) {
                            Log.w(TAG, "Ignoring hot reload for a finishing Activity host")
                            return@runOnMainThread
                        }
                        val reset = resetNativeModulesForHotReload()
                        if (!reset) {
                            Log.w(TAG, "Ignoring hot reload because native modules could not be replaced")
                            return@runOnMainThread
                        }
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
            // Drives the bottom-right connection badge (HotReloadStatusView);
            // gated internally on the host app's debuggability.
            manager.onStatusChange = { status -> HotReloadStatusView.update(this, status) }
            hotReloadManager = manager
            // Development uses the embedded bundle as its deterministic
            // fallback. An applied OTA must not race the live-reload source.
            // Load it first so the hot-reload auth token embedded in the bundle
            // can be read and attached to the dev server WebSocket URL. The dev
            // server pushes full bundles inline over the WebSocket, so only the
            // ws:// URL is needed (no derived HTTP bundle URL).
            loadFromAssets { _, _ ->
                if (isFinishing || isDestroyed) return@loadFromAssets
                // Best-effort: an empty token (production / unreadable global)
                // leaves the URL unchanged; a non-empty token is appended so a
                // network-exposed (`--lan`) dev server can authenticate this app.
                // The manager reconnects using this same URL, so the token is
                // presented on every reconnection too.
                runtime.readHotReloadToken { token ->
                    hotReloadManager?.connect(HotReloadManager.hotReloadUrl(devUrl, token))
                }
            }
        } else {
            loadAppliedBundleOrAssets()
        }
    }

    private fun registerNativeModules() {
        val registry = NativeModuleRegistry.getInstance(this)
        registry.registerDefaults(runtime.bridge, this)
        createNativeModules().forEach { module ->
            registry.registerAndInitialize(module, runtime.bridge, this)
        }
    }

    /** Visible to package tests so the production hot-reload replacement can be exercised. */
    internal fun resetNativeModulesForHotReload(): Boolean =
        NativeModuleRegistry.getInstance(this).resetDefaultsForHotReload(
            runtime.bridge,
            this,
            ::createNativeModules,
        )

    private fun loadAppliedBundleOrAssets() {
        val otaBundle = OTAModule.activeBundleFile(this)
        if (otaBundle == null) {
            loadFromAssets()
            return
        }

        try {
            val bundleCode = otaBundle.readText(Charsets.UTF_8)
            runtime.loadBundle(bundleCode) { success, errorMessage ->
                if (success) {
                    Log.i(TAG, "Loaded verified OTA bundle ${otaBundle.name}")
                } else {
                    // Prevent a permanently broken startup loop. A runtime
                    // evaluation failure may have partially mutated this V8
                    // context, so the embedded bundle is selected on the next
                    // clean Activity rather than evaluated into the same context.
                    OTAModule.invalidateActiveBundle(this)
                    Log.e(TAG, "OTA bundle evaluation failed; embedded bundle restored for next launch: $errorMessage")
                    if (!isFinishing && !isDestroyed) {
                        recreate()
                    }
                }
            }
        } catch (error: Exception) {
            // The resolver verified the file immediately before this read, but
            // storage can still change in between. Clear stale state and use the
            // immutable asset in the current launch.
            OTAModule.invalidateActiveBundle(this)
            Log.w(TAG, "OTA bundle became unreadable; falling back to assets", error)
            loadFromAssets()
        }
    }

    private fun loadFromAssets(onComplete: ((Boolean, String?) -> Unit)? = null) {
        try {
            val bundleCode = readEmbeddedBundle()
            runtime.loadBundle(bundleCode, onComplete)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load bundle from assets: ${e.message}")
            ErrorOverlayView.show(this, "Failed to load bundle: ${e.message}")
            onComplete?.invoke(false, e.message)
        }
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        intent?.data?.toString()?.let { url ->
            runtime.bridge.dispatchGlobalEvent("url", mapOf("url" to url))
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // Hosts that opt into configChanges retain the same JS runtime, so emit
        // the two environment changes that composables subscribe to. Hosts that
        // recreate the Activity still receive the same values through getInfo.
        runtime.bridge.dispatchGlobalEvent("dimensionsChange", DeviceInfoModule.dimensions(this))
        runtime.bridge.dispatchGlobalEvent(
            "colorScheme:change",
            mapOf("colorScheme" to DeviceInfoModule.colorScheme(newConfig)),
        )
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        ImagePickerModule.onActivityResult(requestCode, resultCode, data)
        CameraModule.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        PermissionsModule.clearActivity(this)
        BackHandlerModule.clearActivity(this)
        ImagePickerModule.clearActivity(this)
        CameraModule.clearActivity(this)
        hotReloadManager?.disconnect()
        HotReloadStatusView.hide(this)
        if (::runtime.isInitialized) {
            runtime.bridge.destroyHost()
            NativeModuleRegistry.getInstance(this).destroyAll(runtime.bridge)
            runtime.release()
        }
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        PermissionsModule.onPermissionsResult(requestCode, permissions, grantResults)
    }

    /**
     * Apply the two hot-reload safety gates to [getDevServerUrl].
     *
     * Returns the URL only when this build is debuggable *and* the URL points at
     * a loopback / private-network dev server. Otherwise returns null, which
     * makes [loadBundle] fall through to the embedded/OTA bundle.
     *
     * Without the debuggable gate a release APK built from the documented host
     * pattern connected to a plaintext `ws://` endpoint and evaluated whatever
     * JavaScript arrived there, with full native-module privileges — the same
     * path iOS gates behind `#if DEBUG`, and the same flag [ErrorOverlayView]
     * and [HotReloadStatusView] already check.
     */
    private fun resolveDevServerUrl(): String? {
        val configured = getDevServerUrl() ?: return null

        val isDebuggable =
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

        return when (DevServerPolicy.evaluate(configured, isDebuggable)) {
            DevServerPolicy.Verdict.ALLOWED -> configured
            DevServerPolicy.Verdict.ALLOWED_UNVERIFIED_HOSTNAME -> {
                Log.w(
                    TAG,
                    "Hot reload dev server '$configured' is a hostname, not a private IP " +
                        "literal; connecting because this build is debuggable.",
                )
                configured
            }
            DevServerPolicy.Verdict.REJECTED_NOT_DEBUGGABLE -> {
                Log.e(
                    TAG,
                    "Ignoring getDevServerUrl() = $configured: hot reload requires a debuggable " +
                        "build. Loading the embedded/OTA bundle instead.",
                )
                null
            }
            DevServerPolicy.Verdict.REJECTED_PUBLIC_ADDRESS -> {
                Log.e(
                    TAG,
                    "Refusing hot reload dev server '$configured': the host is not a loopback " +
                        "or private-network address. Hot reload evaluates unauthenticated " +
                        "JavaScript with native-module privileges.",
                )
                null
            }
            DevServerPolicy.Verdict.REJECTED_UNPARSEABLE -> {
                Log.e(TAG, "Refusing hot reload dev server '$configured': not a parseable URL.")
                null
            }
        }
    }

    /**
     * Default back action, invoked when JS did not consume `hardware:backPress`.
     * Override to change what "back" does when the Vue app has no handler for it.
     */
    protected open fun performDefaultBackAction() {
        if (!isFinishing) {
            finish()
        }
    }
}
