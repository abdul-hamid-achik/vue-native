package com.vuenative.example.counter

import com.vuenative.core.VueNativeActivity

/**
 * Counter example app.
 *
 * The Vue bundle is built from examples/counter/ and copied to
 * src/main/assets/vue-native-bundle.js before running.
 */
class MainActivity : VueNativeActivity() {
    override fun getBundleAssetPath(): String = "vue-native-bundle.js"
    override fun getDevServerUrl(): String? = "ws://10.0.2.2:5173"  // Emulator → host machine
}
