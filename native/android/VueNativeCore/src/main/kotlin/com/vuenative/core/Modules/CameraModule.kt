package com.vuenative.core

/**
 * CameraModule — backs the useCamera() composable.
 *
 * Camera capture (launchCamera, launchImageLibrary) requires an Activity-level
 * startActivityForResult / registerForActivityResult hook. This stub ensures
 * the module exists so JS composables can import it without crashing.
 *
 * To enable camera in your app:
 * 1. Override onActivityResult in your VueNativeActivity subclass.
 * 2. Register a concrete CameraModule implementation that stores the Activity reference.
 */
class CameraModule : NativeModule {
    override val moduleName = "Camera"

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        callback(
            null,
            "Camera.$method requires Activity integration. " +
            "Register a CameraModule subclass with your VueNativeActivity that " +
            "implements launchCamera/launchImageLibrary via registerForActivityResult."
        )
    }
}
