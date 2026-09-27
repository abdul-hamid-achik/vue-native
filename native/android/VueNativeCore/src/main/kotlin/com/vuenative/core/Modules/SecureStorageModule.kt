package com.vuenative.core

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Secure key-value storage backed by [EncryptedSharedPreferences].
 *
 * ## Access-control gap (documented, not silently "fixed")
 *
 * The master key is built with `MasterKey.KeyScheme.AES256_GCM` and
 * `setUserAuthenticationRequired` is left at its default of **false**. The key
 * material itself is protected by the Android Keystore (hardware-backed where
 * available) and never leaves it, so values are encrypted at rest — but any code
 * executing inside the app process, including a malicious JS bundle, can call
 * `get`/`set`/`clear` without the user authenticating. That is the same class of
 * gap the Apple implementation had before `kSecAttrAccessControl` was added.
 *
 * Closing it properly requires a `MasterKey` built with
 * `setUserAuthenticationRequired(true, timeoutSeconds)` AND an Activity-bound
 * `BiometricPrompt`/`CryptoObject` to satisfy the auth requirement. A background
 * module `invoke` has no Activity to bind to, so a half-measure here would only
 * make the module fail unpredictably. The `*Protected` methods below therefore
 * report the limitation instead of pretending to be gated.
 */
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
        val p = prefs ?: run {
            callback(null, "SecureStorage not initialized")
            return
        }
        when (method) {
            "get" -> {
                val key = args.getOrNull(0)?.toString() ?: run {
                    callback(null, "Missing key")
                    return
                }
                callback(p.getString(key, null), null)
            }
            "set" -> {
                val key = args.getOrNull(0)?.toString() ?: run {
                    callback(null, "Missing key")
                    return
                }
                val value = args.getOrNull(1)?.toString() ?: run {
                    callback(null, "Missing value")
                    return
                }
                p.edit().putString(key, value).apply()
                callback(null, null)
            }
            "remove" -> {
                val key = args.getOrNull(0)?.toString() ?: run {
                    callback(null, "Missing key")
                    return
                }
                p.edit().remove(key).apply()
                callback(null, null)
            }
            "clear" -> {
                p.edit().clear().apply()
                callback(null, null)
            }
            // Cross-platform parity with the Apple `*Protected` methods, which
            // are gated by `kSecAttrAccessControl`. See the class doc: a proper
            // Android gate needs an Activity-bound BiometricPrompt/CryptoObject
            // that a background module invoke cannot supply, so this fails
            // loudly instead of silently serving unprotected storage under a
            // name that implies it is protected.
            "getProtected", "setProtected", "removeProtected" -> {
                callback(
                    null,
                    "SecureStorage: biometry-gated storage is not available on Android; " +
                        "use host-provided BiometricPrompt-protected storage"
                )
            }
            else -> callback(null, "Unknown method: $method")
        }
    }
}
