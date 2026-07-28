package com.vuenative.core

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager

/**
 * Battery state module. Mirrors the runtime `useBattery` composable contract
 * (`packages/runtime/src/composables/useBattery.ts`): `getBatteryInfo` resolves
 * to `{ level: Double | null, isCharging: Boolean | null }`.
 *
 * `level` is a 0..1 fraction derived from `EXTRA_LEVEL`/`EXTRA_SCALE`; `isCharging`
 * is true when `EXTRA_STATUS` reports charging or full. Both are null when the
 * device exposes no battery (e.g. an emulator without a battery service) so the
 * composable can report `isSupported = false`.
 */
class BatteryModule : NativeModule {
    override val moduleName = "Battery"

    private var appContext: Context? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        appContext = context.applicationContext
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        when (method) {
            "getBatteryInfo" -> callback(getBatteryInfo(), null)
            else -> callback(null, "Unknown method: $method")
        }
    }

    private fun getBatteryInfo(): Map<String, Any?> {
        val ctx = appContext ?: return mapOf("level" to null, "isCharging" to null)
        return try {
            // ACTION_BATTERY_CHANGED is a sticky broadcast; passing a null receiver
            // returns the last-sticky intent without registering anything.
            val batteryIntent = ctx.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            if (batteryIntent == null) {
                mapOf("level" to null, "isCharging" to null)
            } else {
                mapOf(
                    "level" to batteryLevel(batteryIntent),
                    "isCharging" to batteryCharging(batteryIntent),
                )
            }
        } catch (e: Exception) {
            mapOf("level" to null, "isCharging" to null)
        }
    }

    /** Battery level as a 0..1 fraction, or null when the intent lacks level/scale. */
    internal fun batteryLevel(intent: Intent): Double? {
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (level < 0 || scale <= 0) return null
        return level.toDouble() / scale.toDouble()
    }

    /** True when charging or full, false otherwise, null when status is absent. */
    internal fun batteryCharging(intent: Intent): Boolean? {
        val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        if (status < 0) return null
        return status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
    }

    override fun destroy() {
        appContext = null
    }
}
