package com.vuenative.core

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner

class AppStateModule : NativeModule {
    override val moduleName = "AppState"
    @Volatile private var currentState = "active"
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lifecycleObserver: DefaultLifecycleObserver? = null
    @Volatile private var destroyed = false

    override fun initialize(context: Context, bridge: NativeBridge) {
        destroyed = false
        runOnMain {
            if (destroyed) return@runOnMain
            try {
                val lifecycle = ProcessLifecycleOwner.get().lifecycle
                lifecycleObserver?.let { lifecycle.removeObserver(it) }
                val observer = object : DefaultLifecycleObserver {
                    override fun onStart(owner: LifecycleOwner) {
                        currentState = "active"
                        bridge.dispatchGlobalEvent("appState:change", mapOf("state" to "active"))
                    }
                    override fun onStop(owner: LifecycleOwner) {
                        currentState = "background"
                        bridge.dispatchGlobalEvent("appState:change", mapOf("state" to "background"))
                    }
                }
                lifecycleObserver = observer
                lifecycle.addObserver(observer)
            } catch (e: Exception) {
                Log.e("VueNative", "AppStateModule init failed", e)
            }
        }
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        when (method) {
            "getState" -> callback(mapOf("state" to currentState), null)
            else -> callback(null, "Unknown method: $method")
        }
    }

    override fun destroy() {
        destroyed = true
        runOnMain {
            lifecycleObserver?.let { observer ->
                runCatching {
                    ProcessLifecycleOwner.get().lifecycle.removeObserver(observer)
                }.onFailure { error ->
                    Log.w("VueNative", "AppStateModule cleanup failed", error)
                }
            }
            lifecycleObserver = null
        }
    }

    private fun runOnMain(action: () -> Unit) {
        if (Looper.myLooper() === Looper.getMainLooper()) {
            action()
        } else {
            mainHandler.post(action)
        }
    }
}
