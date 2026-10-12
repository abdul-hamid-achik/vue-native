package com.vuenative.core

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.io.File
import java.io.IOException
import java.security.GeneralSecurityException

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

    companion object {
        private const val TAG = "VueNative-SecureStorage"
        private const val STORE_NAME = "vue_native_secure_storage"

        /**
         * Open the encrypted store, recovering once from an undecryptable file.
         *
         * After an Auto Backup restore to a new device the backed-up preferences
         * are still there, but the Keystore master key that encrypted them does
         * not migrate. `create` then throws on every launch and the module stays
         * dead. On the first crypto or I/O failure this deletes the store with
         * `deleteStore` and calls `create` once more. A second failure propagates,
         * as it always did.
         */
        internal fun openWithRecovery(
            create: () -> SharedPreferences,
            deleteStore: () -> Unit,
        ): SharedPreferences = try {
            create()
        } catch (error: Exception) {
            // Only a crypto or I/O failure means the stored keyset cannot be read.
            // Anything else, such as a transient Keystore runtime error, propagates
            // and leaves the store alone, since it may open on the next launch.
            if (error !is GeneralSecurityException && error !is IOException) throw error
            Log.w(TAG, "Secure store could not be decrypted; recreating it once", error)
            deleteStore()
            create()
        }

        /** Remove the store file so it can be created afresh. */
        private fun deleteStoreFile(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                context.deleteSharedPreferences(STORE_NAME)
            } else {
                File(context.applicationInfo.dataDir, "shared_prefs/$STORE_NAME.xml").delete()
            }
        }
    }

    override fun initialize(context: Context, bridge: NativeBridge) {
        // Built outside the recovery: a master key failure says nothing about the
        // stored data, so it must never cause the store to be deleted.
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        prefs = openWithRecovery(
            create = {
                EncryptedSharedPreferences.create(
                    context,
                    STORE_NAME,
                    masterKey,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
                )
            },
            deleteStore = { deleteStoreFile(context) },
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
