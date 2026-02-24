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

    fun register(module: NativeModule) {
        modules[module.moduleName] = module
    }

    fun registerDefaults(bridge: NativeBridge) {
        val ctx = context
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
        ).forEach { m ->
            register(m)
            m.initialize(ctx, bridge)
        }
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
