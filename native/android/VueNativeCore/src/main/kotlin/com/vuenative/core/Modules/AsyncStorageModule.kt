package com.vuenative.core

import android.content.Context
import android.content.SharedPreferences

class AsyncStorageModule : NativeModule {
    override val moduleName = "AsyncStorage"
    private var prefs: SharedPreferences? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        prefs = context.getSharedPreferences("vue_native_async_storage", Context.MODE_PRIVATE)
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val p = prefs ?: run { callback(null, "Storage not initialized"); return }
        when (method) {
            "getItem" -> {
                val key = args.getOrNull(0)?.toString() ?: run { callback(null, "Missing key"); return }
                callback(p.getString(key, null), null)
            }
            "setItem" -> {
                val key   = args.getOrNull(0)?.toString() ?: run { callback(null, "Missing key"); return }
                val value = args.getOrNull(1)?.toString() ?: run { callback(null, "Missing value"); return }
                p.edit().putString(key, value).apply()
                callback(null, null)
            }
            "removeItem" -> {
                val key = args.getOrNull(0)?.toString() ?: run { callback(null, "Missing key"); return }
                p.edit().remove(key).apply()
                callback(null, null)
            }
            "getAllKeys" -> {
                callback(p.all.keys.toList(), null)
            }
            "clear" -> {
                p.edit().clear().apply()
                callback(null, null)
            }
            "multiGet" -> {
                val keys = (args.getOrNull(0) as? List<*>)?.map { it?.toString() ?: "" } ?: emptyList()
                val result = keys.map { k -> listOf(k, p.getString(k, null)) }
                callback(result, null)
            }
            "multiSet" -> {
                val pairs = args.getOrNull(0) as? List<*> ?: emptyList<Any>()
                val editor = p.edit()
                pairs.forEach { pair ->
                    val kv = pair as? List<*>
                    val k = kv?.getOrNull(0)?.toString()
                    val v = kv?.getOrNull(1)?.toString()
                    if (k != null && v != null) editor.putString(k, v)
                }
                editor.apply()
                callback(null, null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }
}
