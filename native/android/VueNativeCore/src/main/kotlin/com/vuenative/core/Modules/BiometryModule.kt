package com.vuenative.core

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/**
 * BiometryModule — backs the useBiometry() composable.
 *
 * Availability checks use BiometricManager. Authentication uses the active
 * VueNativeActivity (an AppCompat/FragmentActivity) supplied by the registry.
 */
class BiometryModule : NativeModule {
    override val moduleName = "Biometry"
    private var context: Context? = null
    private var activity: FragmentActivity? = null
    private var prompt: BiometricPrompt? = null
    private var pendingAuthentication: ((Any?, String?) -> Unit)? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
        this.activity = context as? FragmentActivity
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "getSupportedBiometry" -> {
                val ctx = context ?: run {
                    callback("none", null)
                    return
                }
                val biometricManager = BiometricManager.from(ctx)
                val result = when (biometricManager.canAuthenticate(
                    BiometricManager.Authenticators.BIOMETRIC_STRONG
                )) {
                    BiometricManager.BIOMETRIC_SUCCESS -> "faceID" // Android doesn't distinguish
                    BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "none"
                    BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "none"
                    BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "biometric" // HW present, not enrolled
                    else -> "none"
                }
                callback(result, null)
            }
            "isAvailable" -> {
                val ctx = context ?: run {
                    callback(false, null)
                    return
                }
                callback(canAuthenticate(ctx), null)
            }
            "authenticate" -> {
                authenticate(args.getOrNull(0)?.toString() ?: "Authenticate", callback)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }

    private fun canAuthenticate(ctx: Context): Boolean =
        BiometricManager.from(ctx).canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG,
        ) == BiometricManager.BIOMETRIC_SUCCESS

    private fun authenticate(reason: String, callback: (Any?, String?) -> Unit) {
        val host = activity ?: run {
            callback(null, "Biometry.authenticate requires an active VueNativeActivity")
            return
        }
        if (pendingAuthentication != null) {
            callback(null, "Biometry.authenticate already has an active prompt")
            return
        }
        if (!canAuthenticate(host)) {
            callback(
                mapOf("success" to false, "error" to "Biometric authentication is unavailable or not enrolled"),
                null,
            )
            return
        }

        pendingAuthentication = callback
        host.runOnUiThread {
            if (host.isFinishing || host.isDestroyed) {
                finishAuthentication(false, "The native host is no longer active")
                return@runOnUiThread
            }

            val authenticationPrompt = BiometricPrompt(
                host,
                ContextCompat.getMainExecutor(host),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                        finishAuthentication(true, null)
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        finishAuthentication(false, errString.toString())
                    }
                },
            )
            prompt = authenticationPrompt
            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("Biometric authentication")
                .setSubtitle(reason)
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText("Cancel")
                .build()
            authenticationPrompt.authenticate(promptInfo)
        }
    }

    private fun finishAuthentication(success: Boolean, error: String?) {
        val callback = pendingAuthentication ?: return
        pendingAuthentication = null
        prompt = null
        val result = mutableMapOf<String, Any>("success" to success)
        if (error != null) result["error"] = error
        callback(result, null)
    }

    override fun destroy() {
        prompt?.cancelAuthentication()
        prompt = null
        pendingAuthentication?.invoke(
            mapOf("success" to false, "error" to "The native host was destroyed"),
            null,
        )
        pendingAuthentication = null
        activity = null
        context = null
    }
}
