package com.vuenative.core

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Looper
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import java.util.concurrent.atomic.AtomicInteger

class GeolocationModule : NativeModule {
    override val moduleName = "Geolocation"

    private var fusedClient: FusedLocationProviderClient? = null
    private var context: Context? = null
    private var bridge: NativeBridge? = null
    private val watchIds = mutableSetOf<Int>()
    private val nextWatchId = AtomicInteger(1)
    private var locationCallback: LocationCallback? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
        this.bridge = bridge
        fusedClient = LocationServices.getFusedLocationProviderClient(context.applicationContext)
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "getCurrentPosition" -> {
                val ctx = context ?: run {
                    callback(null, "Not initialized")
                    return
                }
                if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION)
                    != PackageManager.PERMISSION_GRANTED
                ) {
                    callback(null, "Location permission not granted. Request permission first.")
                    return
                }
                fusedClient?.lastLocation
                    ?.addOnSuccessListener { location ->
                        if (location != null) {
                            callback(locationPayload(location), null)
                        } else {
                            callback(null, "Location unavailable — no last known position")
                        }
                    }
                    ?.addOnFailureListener { e ->
                        callback(null, e.message ?: "Location error")
                    }
            }
            "watchPosition" -> startWatch(callback)
            "clearWatch" -> {
                val id = (args.getOrNull(0) as? Number)?.toInt()
                if (id != null) clearWatch(id)
                callback(null, null)
            }
            "requestAuthorization" -> {
                // Authorization must be handled via PermissionsModule / Activity; signal success
                // so composables can call getCurrentPosition without a separate step.
                callback(mapOf("status" to "whenInUse"), null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }

    private fun startWatch(callback: (Any?, String?) -> Unit) {
        val ctx = context ?: run {
            callback(null, "Not initialized")
            return
        }
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            callback(null, "Location permission not granted. Request permission first.")
            return
        }

        val id = nextWatchId.getAndIncrement()
        watchIds += id
        if (locationCallback == null) {
            val updates = object : LocationCallback() {
                override fun onLocationResult(result: LocationResult) {
                    val location = result.lastLocation ?: return
                    bridge?.dispatchGlobalEvent("location:update", locationPayload(location))
                }
            }
            locationCallback = updates
            val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1_000L)
                .setMinUpdateIntervalMillis(500L)
                .build()
            fusedClient?.requestLocationUpdates(request, updates, Looper.getMainLooper())
                ?.addOnFailureListener { error ->
                    watchIds.clear()
                    locationCallback = null
                    bridge?.dispatchGlobalEvent(
                        "location:error",
                        mapOf("message" to (error.message ?: "Location watch failed")),
                    )
                }
        }
        callback(id, null)
    }

    private fun clearWatch(id: Int) {
        watchIds.remove(id)
        if (watchIds.isEmpty()) {
            locationCallback?.let { fusedClient?.removeLocationUpdates(it) }
            locationCallback = null
        }
    }

    private fun locationPayload(location: android.location.Location): Map<String, Any> = mapOf(
        "latitude" to location.latitude,
        "longitude" to location.longitude,
        "altitude" to location.altitude,
        "accuracy" to location.accuracy.toDouble(),
        "altitudeAccuracy" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && location.hasVerticalAccuracy()) {
            location.verticalAccuracyMeters.toDouble()
        } else {
            0.0
        },
        "heading" to location.bearing.toDouble(),
        "speed" to location.speed.toDouble(),
        "timestamp" to location.time,
    )

    override fun destroy() {
        locationCallback?.let { fusedClient?.removeLocationUpdates(it) }
        locationCallback = null
        watchIds.clear()
        nextWatchId.set(1)
        bridge = null
        fusedClient = null
        context = null
    }
}
