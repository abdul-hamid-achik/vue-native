package com.vuenative.core

import android.content.Context

/**
 * Protocol for all native modules. Mirrors Swift NativeModule protocol.
 */
interface NativeModule {
    val moduleName: String

    /** Async invocation -- calls callback(result, error) when done. */
    fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (result: Any?, error: String?) -> Unit
    )

    /** Synchronous invocation -- returns result immediately. */
    fun invokeSync(method: String, args: List<Any?>, bridge: NativeBridge): Any? = null

    /** Called once when registered. Override to set up listeners. */
    fun initialize(context: Context, bridge: NativeBridge) {}

    /** Called when the module is being destroyed. */
    fun destroy() {}
}
