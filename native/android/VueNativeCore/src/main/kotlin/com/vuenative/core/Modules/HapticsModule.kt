package com.vuenative.core

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

class HapticsModule : NativeModule {
    override val moduleName = "Haptics"
    private var vibrator: Vibrator? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        when (method) {
            "vibrate", "impact" -> {
                val style = args.getOrNull(0)?.toString() ?: "medium"
                vibrate(style)
                callback(null, null)
            }
            "selectionChanged" -> {
                vibrate("light")
                callback(null, null)
            }
            "notificationOccurred" -> {
                val type = args.getOrNull(0)?.toString() ?: "success"
                vibrate(type)
                callback(null, null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }

    private fun vibrate(style: String) {
        val vib = vibrator ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = when (style) {
                "light" -> VibrationEffect.createOneShot(30, 80)
                "medium" -> VibrationEffect.createOneShot(50, 150)
                "heavy" -> VibrationEffect.createOneShot(80, 200)
                "success" -> VibrationEffect.createWaveform(longArrayOf(0, 50, 50, 50), intArrayOf(0, 180, 0, 100), -1)
                "warning" -> VibrationEffect.createOneShot(100, 200)
                "error" -> VibrationEffect.createWaveform(longArrayOf(0, 100, 50, 100), intArrayOf(0, 255, 0, 255), -1)
                else -> VibrationEffect.createOneShot(50, 150)
            }
            vib.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            vib.vibrate(50)
        }
    }
}
