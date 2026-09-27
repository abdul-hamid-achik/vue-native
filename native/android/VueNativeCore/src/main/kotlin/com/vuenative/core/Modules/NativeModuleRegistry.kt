package com.vuenative.core

import android.content.Context
import android.util.Log

class NativeModuleRegistry private constructor(private val context: Context) {
    companion object {
        @Volatile private var instance: NativeModuleRegistry? = null
        fun getInstance(context: Context): NativeModuleRegistry =
            instance ?: synchronized(this) {
                instance ?: NativeModuleRegistry(context.applicationContext).also { instance = it }
            }
    }

    /** Thread-safe module map. Registration happens on the main thread during onCreate,
     *  but invoke can be called from the bridge's operation processing which also runs on main.
     *  Using ConcurrentHashMap guards against any future multi-thread access patterns. */
    private val modules = java.util.concurrent.ConcurrentHashMap<String, NativeModule>()
    @Volatile private var activeBridge: NativeBridge? = null

    @Synchronized
    fun register(module: NativeModule) {
        val previous = modules.put(module.moduleName, module)
        if (previous != null && previous !== module) {
            runCatching { previous.destroy() }
                .onFailure { error ->
                    Log.w(
                        "NativeModuleRegistry",
                        "Failed to destroy replaced module ${previous.moduleName}: ${error.message}",
                    )
                }
        }
    }

    /** Register and initialize one module without exposing a failed instance. */
    @Synchronized
    fun registerAndInitialize(
        module: NativeModule,
        bridge: NativeBridge,
        hostContext: Context = context,
    ): Boolean {
        register(module)
        return runCatching {
            module.initialize(hostContext, bridge)
        }.fold(
            onSuccess = { true },
            onFailure = { error ->
                modules.remove(module.moduleName, module)
                runCatching { module.destroy() }
                Log.e(
                    "NativeModuleRegistry",
                    "Failed to initialize module ${module.moduleName}",
                    error,
                )
                false
            },
        )
    }

    /**
     * Destroy and unregister every module owned by the host identified by [owner].
     * Activities call this before releasing their JS runtime so observers,
     * sockets, sensors, and media resources do not survive host recreation.
     *
     * [owner] is mandatory: an older Activity may finish after a replacement
     * Activity has already installed a new bridge, and it must not tear down the
     * new host's modules. Callers that legitimately need an unguarded teardown
     * (an *incoming* host replacing the previous snapshot) use
     * [destroyPreviousSnapshot] instead.
     */
    @Synchronized
    fun destroyAll(owner: NativeBridge) {
        if (activeBridge !== owner) return
        destroyPreviousSnapshot()
    }

    /**
     * Unconditionally destroy the current module snapshot and forget the active
     * bridge. Only valid while holding the monitor, from a code path that is
     * installing a replacement snapshot — the stale-host guard in [destroyAll]
     * protects an *outgoing* host, which is not the situation here.
     *
     * `internal` (not public) so a consumer app cannot bypass the stale-host
     * guard by accident; unit tests in this module use it to reset state.
     */
    @Synchronized
    internal fun destroyPreviousSnapshot() {
        val registeredModules = modules.values.toSet()
        modules.clear()
        activeBridge = null
        registeredModules.forEach { module ->
            runCatching { module.destroy() }
                .onFailure { error ->
                    Log.w(
                        "NativeModuleRegistry",
                        "Failed to destroy module ${module.moduleName}: ${error.message}",
                    )
                }
        }
    }

    @Synchronized
    fun registerDefaults(bridge: NativeBridge, hostContext: Context = context) {
        // Reinitialization must be an exact snapshot. This also removes a
        // generated module that disappeared since the previous host started.
        destroyPreviousSnapshot()
        activeBridge = bridge
        listOf(
            HapticsModule(),
            AccessibilityModule(),
            AsyncStorageModule(),
            ClipboardModule(),
            DeviceInfoModule(),
            BatteryModule(),
            NetworkModule(),
            AppStateModule(),
            LinkingModule(),
            ShareModule(),
            AnimationModule(),
            KeyboardModule(),
            PermissionsModule(),
            GeolocationModule(),
            NotificationsModule(),
            HttpModule(),
            BiometryModule(),
            CameraModule(),
            BackHandlerModule(),
            SecureStorageModule(),
            WebSocketModule(),
            FileSystemModule(),
            SensorsModule(),
            AudioModule(),
            DatabaseModule(),
            PerformanceModule(),
            BackgroundTaskModule(),
            OTAModule(),
            IAPModule(),
            SocialAuthModule(),
            BluetoothModule(),
            CalendarModule(),
            ContactsModule(),
            InspectorModule(),
            ImagePickerModule(),
        ).forEach { module -> registerAndInitialize(module, bridge, hostContext) }

        // Register generated modules from <native> blocks
        registerGeneratedModules(hostContext, bridge)
    }

    /**
     * Replace the complete module snapshot for a hot-reloaded JavaScript world.
     * The bridge generation must advance before module destruction so any
     * teardown callbacks from the old snapshot cannot resolve reused JS IDs.
     *
     * A stale Activity must not replace modules owned by a newer host.
     */
    @Synchronized
    fun resetDefaultsForHotReload(
        owner: NativeBridge,
        hostContext: Context,
    ): Boolean = resetDefaultsForHotReload(owner, hostContext) { emptyList() }

    /**
     * Replace the complete module snapshot and install application modules last.
     * The provider is evaluated only for the active owner and before mutating the
     * current snapshot, so a stale host or construction failure has no side effects.
     */
    @Synchronized
    fun resetDefaultsForHotReload(
        owner: NativeBridge,
        hostContext: Context,
        customModuleProvider: () -> List<NativeModule>,
    ): Boolean {
        if (activeBridge !== owner) return false

        val customModules = try {
            customModuleProvider()
        } catch (error: Exception) {
            Log.e(
                "NativeModuleRegistry",
                "Failed to create application modules for hot reload",
                error,
            )
            return false
        }
        owner.clearAllRegistries()
        registerDefaults(owner, hostContext)
        customModules.forEach { module ->
            registerAndInitialize(module, owner, hostContext)
        }
        return true
    }

    fun getModule(name: String): NativeModule? = modules[name]

    fun invoke(
        moduleName: String,
        methodName: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (result: Any?, error: String?) -> Unit
    ) {
        val module = modules[moduleName]
        if (module == null) {
            callback(null, "No module registered: $moduleName")
            return
        }
        try {
            module.invoke(methodName, args, bridge, callback)
        } catch (e: Throwable) {
            // Throwable, not Exception: modules reach into platform APIs whose
            // absence on an older device surfaces as NoSuchMethodError, and an
            // uncaught Error here would terminate the process instead of
            // rejecting one JS promise.
            Log.e("NativeModuleRegistry", "Module $moduleName.$methodName failed", e)
            callback(null, e.message ?: "Module error")
        }
    }

    fun invokeSync(moduleName: String, methodName: String, args: List<Any?>, bridge: NativeBridge): Any? {
        val module = modules[moduleName]
        if (module == null) {
            Log.w("NativeModuleRegistry", "invokeSync: No module registered: $moduleName")
            return null
        }
        return module.invokeSync(methodName, args, bridge)
    }
}
