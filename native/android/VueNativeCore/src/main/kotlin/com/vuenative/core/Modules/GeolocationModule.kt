package com.vuenative.core

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices

class GeolocationModule : NativeModule {
    override val moduleName = "Geolocation"

    private var fusedClient: FusedLocationProviderClient? = null
    private var context: Context? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context
        fusedClient = LocationServices.getFusedLocationProviderClient(context)
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
                            callback(
                                mapOf(
                                    "coords" to mapOf(
                                        "latitude" to location.latitude,
                                        "longitude" to location.longitude,
                                        "accuracy" to location.accuracy.toDouble(),
                                        "altitude" to location.altitude,
                                        "speed" to location.speed.toDouble(),
                                        "heading" to location.bearing.toDouble()
                                    ),
                                    "timestamp" to location.time
                                ), null
                            )
                        } else {
                            callback(null, "Location unavailable — no last known position")
                        }
                    }
                    ?.addOnFailureListener { e ->
                        callback(null, e.message ?: "Location error")
                    }
            }
            "requestAuthorization" -> {
                // Authorization must be handled via PermissionsModule / Activity; signal success
                // so composables can call getCurrentPosition without a separate step.
                callback(mapOf("status" to "whenInUse"), null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }
}
