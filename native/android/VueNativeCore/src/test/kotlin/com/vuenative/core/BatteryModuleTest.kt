package com.vuenative.core

import android.content.Context
import android.content.Intent
import android.os.BatteryManager
import android.widget.FrameLayout
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class BatteryModuleTest {
    private lateinit var context: Context
    private lateinit var bridge: NativeBridge
    private lateinit var module: BatteryModule

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        bridge = NativeBridge(context).also { it.hostContainer = FrameLayout(context) }
        module = BatteryModule().also { it.initialize(context, bridge) }
    }

    private fun batteryIntent(level: Int, scale: Int, status: Int): Intent =
        Intent(Intent.ACTION_BATTERY_CHANGED).apply {
            putExtra(BatteryManager.EXTRA_LEVEL, level)
            putExtra(BatteryManager.EXTRA_SCALE, scale)
            putExtra(BatteryManager.EXTRA_STATUS, status)
        }

    // -------------------------------------------------------------------------
    // getBatteryInfo — result shape (no crash, keys present)
    // -------------------------------------------------------------------------

    @Test
    fun getBatteryInfoReturnsExpectedShape() {
        var result: Any? = null
        var callbackError: String? = "not_called"

        module.invoke("getBatteryInfo", emptyList(), bridge) { value, error ->
            result = value
            callbackError = error
        }

        assertNull("getBatteryInfo should not error", callbackError)
        assertNotNull("getBatteryInfo should return a result", result)
        val info = result as Map<*, *>
        assertTrue("result should contain 'level'", info.containsKey("level"))
        assertTrue("result should contain 'isCharging'", info.containsKey("isCharging"))
    }

    // -------------------------------------------------------------------------
    // batteryLevel — 0..1 fraction from EXTRA_LEVEL / EXTRA_SCALE
    // -------------------------------------------------------------------------

    @Test
    fun batteryLevelComputesFraction() {
        assertEquals(0.5, module.batteryLevel(batteryIntent(50, 100, BatteryManager.BATTERY_STATUS_CHARGING))!!, 0.0001)
        assertEquals(1.0, module.batteryLevel(batteryIntent(100, 100, BatteryManager.BATTERY_STATUS_FULL))!!, 0.0001)
        assertEquals(0.0, module.batteryLevel(batteryIntent(0, 100, BatteryManager.BATTERY_STATUS_NOT_CHARGING))!!, 0.0001)
    }

    @Test
    fun batteryLevelNullWhenMissing() {
        // No level/scale extras -> getIntExtra returns the -1 default.
        assertNull(module.batteryLevel(Intent(Intent.ACTION_BATTERY_CHANGED)))
        // A non-positive scale must not divide by zero.
        assertNull(module.batteryLevel(batteryIntent(50, 0, BatteryManager.BATTERY_STATUS_CHARGING)))
    }

    // -------------------------------------------------------------------------
    // batteryCharging — true for CHARGING/FULL, false otherwise, null if absent
    // -------------------------------------------------------------------------

    @Test
    fun batteryChargingTrueForChargingAndFull() {
        assertEquals(true, module.batteryCharging(batteryIntent(50, 100, BatteryManager.BATTERY_STATUS_CHARGING)))
        assertEquals(true, module.batteryCharging(batteryIntent(100, 100, BatteryManager.BATTERY_STATUS_FULL)))
    }

    @Test
    fun batteryChargingFalseWhenDischarging() {
        assertEquals(false, module.batteryCharging(batteryIntent(50, 100, BatteryManager.BATTERY_STATUS_DISCHARGING)))
        assertEquals(false, module.batteryCharging(batteryIntent(50, 100, BatteryManager.BATTERY_STATUS_NOT_CHARGING)))
    }

    @Test
    fun batteryChargingNullWhenStatusMissing() {
        assertNull(module.batteryCharging(Intent(Intent.ACTION_BATTERY_CHANGED)))
    }

    // -------------------------------------------------------------------------
    // Unknown method returns an error
    // -------------------------------------------------------------------------

    @Test
    fun unknownMethodReturnsError() {
        var callbackError: String? = null
        module.invoke("bogus", emptyList(), bridge) { _, error -> callbackError = error }
        assertNotNull(callbackError)
    }
}
