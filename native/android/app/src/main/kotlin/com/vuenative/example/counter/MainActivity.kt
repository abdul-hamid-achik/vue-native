package com.vuenative.example.counter

import com.vuenative.core.VueNativeActivity

/**
 * Counter example app.
 *
 * The Vue bundle is built from examples/counter/ and copied to
 * src/main/assets/vue-native-bundle.js before running.
 *
 * The hot-reload dev-server URL is deliberately NOT hard-coded here. It comes
 * from [DevServer], which exists twice:
 *
 * - `src/debug/kotlin/.../DevServer.kt`   → `ws://10.0.2.2:5173`
 * - `src/release/kotlin/.../DevServer.kt` → `null`
 *
 * so a release build of this example cannot even be compiled with a dev server
 * wired in. [VueNativeActivity] additionally ignores [getDevServerUrl] in any
 * non-debuggable build, so this is belt-and-braces.
 */
class MainActivity : VueNativeActivity() {
    override fun getBundleAssetPath(): String = "vue-native-bundle.js"
    override fun getDevServerUrl(): String? = DevServer.url
}
