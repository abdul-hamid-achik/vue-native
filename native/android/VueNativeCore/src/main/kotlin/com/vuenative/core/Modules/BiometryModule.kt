package com.vuenative.core

import android.content.Context
import androidx.biometric.BiometricManager

/**
 * BiometryModule — backs the useBiometry() composable.
 *
 * Full biometric prompt (authenticate) requires an Activity/Fragment context
 * and a BiometricPrompt instance. The authenticate() method here returns an
 * informative error so developers know to wire it up in a screen component.
 * getSupportedBiometry() works without UI.
 */
class BiometryModule : NativeModule {
    override val moduleName = "Biometry"
    private var context: Context? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context
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
            "authenticate" -> {
                // BiometricPrompt requires a FragmentActivity reference.
                // To use biometry in a screen component, call bridge.invokeNativeModule
                // from an Activity subclass that overrides authenticate() via BiometricPrompt.
                callback(
                    null,
                    "Biometry.authenticate requires Activity context. " +
                    "Override VueNativeActivity.onAuthenticateRequest() to provide BiometricPrompt."
                )
            }
            else -> callback(null, "Unknown method: $method")
        }
    }
}
