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
    private var currentState = "active"

    override fun initialize(context: Context, bridge: NativeBridge) {
        val mainHandler = Handler(Looper.getMainLooper())
        mainHandler.post {
            try {
                ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
                    override fun onStart(owner: LifecycleOwner) {
                        currentState = "active"
                        bridge.dispatchGlobalEvent("appState:change", mapOf("state" to "active"))
                    }
                    override fun onStop(owner: LifecycleOwner) {
                        currentState = "background"
                        bridge.dispatchGlobalEvent("appState:change", mapOf("state" to "background"))
                    }
                })
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
}
