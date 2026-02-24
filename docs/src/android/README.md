# Android Guide

Vue Native targets **Android 7.0+ (API 24)** using Android Views, V8/J2V8, and FlexboxLayout.

## Requirements

- Android 7.0+ (API 24+), targeting API 35
- Android Studio Ladybug+
- JDK 17 (bundled with Android Studio)

For the full step-by-step guide to getting an emulator running, see [Android Setup](./setup.md).

## Native library

The Android native code lives in `native/android/VueNativeCore/` — an Android library module.

```
native/android/VueNativeCore/
└── src/main/kotlin/com/vuenative/core/
    ├── Bridge/
    │   ├── JSRuntime.kt             # V8/J2V8 lifecycle, polyfills
    │   ├── NativeBridge.kt          # Receives batched JS ops → Android Views
    │   └── HotReloadManager.kt      # WebSocket hot reload
    ├── Components/
    │   └── Factories/               # One factory per component
    ├── Modules/                     # Native module implementations
    ├── Styling/
    │   └── StyleEngine.kt           # Style prop → FlexboxLayout/View mapping
    └── VueNativeActivity.kt         # Base Activity for your app
```

## VueNativeActivity

Subclass `VueNativeActivity` for the simplest integration:

```kotlin
import com.vuenative.core.VueNativeActivity

class MainActivity : VueNativeActivity() {
    override fun getBundleAssetPath() = "vue-native-bundle.js"

    override fun getDevServerUrl(): String? {
        return if (BuildConfig.DEBUG) "ws://10.0.2.2:8174" else null
    }
}
```

See the [VueNativeActivity reference](./VueNativeActivity.md) for full details.
