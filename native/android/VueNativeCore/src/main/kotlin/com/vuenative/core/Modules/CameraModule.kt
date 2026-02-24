package com.vuenative.core

import android.content.Context

/**
 * CameraModule — backs the useCamera() composable.
 *
 * Camera capture (launchCamera, launchImageLibrary, captureVideo) requires Activity-level
 * startActivityForResult / registerForActivityResult hook. This stub ensures
 * the module exists so JS composables can import it without crashing.
 *
 * QR code scanning is implemented using the device camera and ZXing/ML Kit
 * when available. The host Activity must provide the implementation.
 *
 * To enable camera in your app:
 * 1. Override onActivityResult in your VueNativeActivity subclass.
 * 2. Register a concrete CameraModule implementation that stores the Activity reference.
 *
 * Methods:
 *   - launchCamera(options)       -- photo capture
 *   - launchImageLibrary(options) -- photo picker
 *   - captureVideo(options)       -- video capture with options: quality, maxDuration, frontCamera
 *   - scanQRCode()                -- start QR code scanning, emits camera:qrDetected events
 *   - stopQRScan()                -- stop QR code scanning
 */
class CameraModule : NativeModule {
    override val moduleName = "Camera"
    private var bridge: NativeBridge? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.bridge = bridge
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "launchCamera", "launchImageLibrary", "captureVideo" -> {
                callback(
                    null,
                    "Camera.$method requires Activity integration. " +
                    "Register a CameraModule subclass with your VueNativeActivity that " +
                    "implements $method via registerForActivityResult."
                )
            }
            "scanQRCode" -> {
                callback(
                    null,
                    "Camera.scanQRCode requires Activity integration and ML Kit dependency. " +
                    "Add com.google.mlkit:barcode-scanning to your app's build.gradle and " +
                    "register a CameraModule subclass that implements QR scanning."
                )
            }
            "stopQRScan" -> {
                // No-op in stub
                callback(null, null)
            }
            else -> callback(null, "Unknown Camera method: $method")
        }
    }
}
