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
     * Destroy and unregister every module owned by this process-wide registry.
     * Activities call this before releasing their JS runtime so observers,
     * sockets, sensors, and media resources do not survive host recreation.
     */
    @Synchronized
    fun destroyAll(owner: NativeBridge? = null) {
        // An older Activity may finish after a replacement Activity has already
        // installed a new bridge. It must not tear down the new host's modules.
        if (owner != null && activeBridge !== owner) return

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
        destroyAll()
        activeBridge = bridge
        listOf(
            HapticsModule(),
            AsyncStorageModule(),
            ClipboardModule(),
            DeviceInfoModule(),
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
        ).forEach { module -> registerAndInitialize(module, bridge, hostContext) }

        // Register generated modules from <native> blocks
        registerGeneratedModules(hostContext, bridge)
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
        } catch (e: Exception) {
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
