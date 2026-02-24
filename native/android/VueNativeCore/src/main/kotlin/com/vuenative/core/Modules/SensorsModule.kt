package com.vuenative.core

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager

class SensorsModule : NativeModule {
    override val moduleName = "Sensors"

    private var sensorManager: SensorManager? = null
    private var bridge: NativeBridge? = null

    private var accelListener: SensorEventListener? = null
    private var gyroListener: SensorEventListener? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.bridge = bridge
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        when (method) {
            "startAccelerometer" -> {
                val interval = intervalToDelay(args.getOrNull(0))
                startAccelerometer(interval, callback)
            }
            "stopAccelerometer" -> {
                stopAccelerometer()
                callback(null, null)
            }
            "startGyroscope" -> {
                val interval = intervalToDelay(args.getOrNull(0))
                startGyroscope(interval, callback)
            }
            "stopGyroscope" -> {
                stopGyroscope()
                callback(null, null)
            }
            "isAvailable" -> {
                val sensorType = args.getOrNull(0)?.toString() ?: "accelerometer"
                val sm = sensorManager
                val available = when (sensorType) {
                    "gyroscope" -> sm?.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null
                    else -> sm?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null
                }
                callback(mapOf("available" to available), null)
            }
            else -> callback(null, "SensorsModule: unknown method '$method'")
        }
    }

    override fun destroy() {
        stopAccelerometer()
        stopGyroscope()
    }

    // -- Accelerometer --

    private fun startAccelerometer(delay: Int, callback: (Any?, String?) -> Unit) {
        val sm = sensorManager ?: run { callback(null, "SensorManager not available"); return }
        val sensor = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            ?: run { callback(null, "Accelerometer not available on this device"); return }

        // Stop previous if running
        stopAccelerometer()

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                bridge?.dispatchGlobalEvent("sensor:accelerometer", mapOf(
                    "x" to event.values[0].toDouble(),
                    "y" to event.values[1].toDouble(),
                    "z" to event.values[2].toDouble(),
                    "timestamp" to (event.timestamp / 1_000_000.0) // ns -> ms
                ))
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        accelListener = listener
        sm.registerListener(listener, sensor, delay)
        callback(null, null)
    }

    private fun stopAccelerometer() {
        accelListener?.let { sensorManager?.unregisterListener(it) }
        accelListener = null
    }

    // -- Gyroscope --

    private fun startGyroscope(delay: Int, callback: (Any?, String?) -> Unit) {
        val sm = sensorManager ?: run { callback(null, "SensorManager not available"); return }
        val sensor = sm.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
            ?: run { callback(null, "Gyroscope not available on this device"); return }

        // Stop previous if running
        stopGyroscope()

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                bridge?.dispatchGlobalEvent("sensor:gyroscope", mapOf(
                    "x" to event.values[0].toDouble(),
                    "y" to event.values[1].toDouble(),
                    "z" to event.values[2].toDouble(),
                    "timestamp" to (event.timestamp / 1_000_000.0) // ns -> ms
                ))
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        gyroListener = listener
        sm.registerListener(listener, sensor, delay)
        callback(null, null)
    }

    private fun stopGyroscope() {
        gyroListener?.let { sensorManager?.unregisterListener(it) }
        gyroListener = null
    }

    // -- Helpers --

    /**
     * Convert JS interval (ms) to Android SensorManager delay (microseconds).
     * Falls back to SENSOR_DELAY_GAME (~20ms) if not specified.
     */
    private fun intervalToDelay(value: Any?): Int {
        val ms = when (value) {
            is Number -> value.toDouble()
            else -> return SensorManager.SENSOR_DELAY_GAME
        }
        return (ms * 1000).toInt() // ms -> microseconds
    }
}
