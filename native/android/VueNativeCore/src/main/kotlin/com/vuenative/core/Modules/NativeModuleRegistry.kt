package com.vuenative.core

import android.content.Context

class NativeModuleRegistry private constructor(private val context: Context) {
    companion object {
        @Volatile private var instance: NativeModuleRegistry? = null
        fun getInstance(context: Context): NativeModuleRegistry =
            instance ?: synchronized(this) {
                instance ?: NativeModuleRegistry(context.applicationContext).also { instance = it }
            }
    }

    private val modules = mutableMapOf<String, NativeModule>()

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
        ).forEach { m ->
            register(m)
            m.initialize(ctx, bridge)
        }
    }

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
        return modules[moduleName]?.invokeSync(methodName, args, bridge)
    }
}
