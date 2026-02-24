package com.vuenative.core

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class SecureStorageModule : NativeModule {
    override val moduleName = "SecureStorage"
    private var prefs: SharedPreferences? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        prefs = EncryptedSharedPreferences.create(
            context,
            "vue_native_secure_storage",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val p = prefs ?: run { callback(null, "SecureStorage not initialized"); return }
        when (method) {
            "get" -> {
                val key = args.getOrNull(0)?.toString() ?: run { callback(null, "Missing key"); return }
                callback(p.getString(key, null), null)
            }
            "set" -> {
                val key = args.getOrNull(0)?.toString() ?: run { callback(null, "Missing key"); return }
                val value = args.getOrNull(1)?.toString() ?: run { callback(null, "Missing value"); return }
                p.edit().putString(key, value).apply()
                callback(null, null)
            }
            "remove" -> {
                val key = args.getOrNull(0)?.toString() ?: run { callback(null, "Missing key"); return }
                p.edit().remove(key).apply()
                callback(null, null)
            }
            "clear" -> {
                p.edit().clear().apply()
                callback(null, null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }
}
