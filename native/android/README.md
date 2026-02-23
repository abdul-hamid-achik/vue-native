# Vue Native — Android

Android implementation of the Vue Native framework. Runs Vue 3 apps on Android using V8 (J2V8) as the JavaScript engine and Android Views with FlexboxLayout for the UI layer.

## Architecture

```
Vue Bundle (IIFE)
     ↓ loaded by JSRuntime (J2V8 / HandlerThread)
 __VN_flushOperations(json)  ← batched operations
     ↓ NativeBridge.processOperations() [main thread]
 ComponentRegistry → NativeComponentFactory
     ↓ createView / updateProp / insertChild
 Android Views (FlexboxLayout, TextView, EditText, RecyclerView…)
     ↓
 Android screen
```

## Module Structure

```
VueNativeCore/
├── Bridge/
│   ├── JSRuntime.kt          — V8 engine on a dedicated HandlerThread
│   ├── NativeBridge.kt       — Processes batched operations on main thread
│   ├── JSPolyfills.kt        — console, setTimeout, fetch, RAF, performance.now
│   ├── HotReloadManager.kt   — WebSocket connection to Vite dev server
│   └── ErrorOverlayView.kt   — Debug error overlay
├── Components/
│   ├── NativeComponentFactory.kt  — Factory interface
│   ├── ComponentRegistry.kt       — Singleton factory registry
│   ├── VTextNodeView.kt           — Text node view for VText children
│   └── Factories/
│       ├── VViewFactory.kt         — FlexboxLayout
│       ├── VTextFactory.kt         — TextView
│       ├── VButtonFactory.kt       — Pressable FlexboxLayout
│       ├── VInputFactory.kt        — EditText with v-model
│       ├── VScrollViewFactory.kt   — ScrollView + FlexboxLayout content
│       ├── VListFactory.kt         — RecyclerView with bridge-managed items
│       ├── VImageFactory.kt        — Coil-based async image loading
│       ├── VSwitchFactory.kt       — SwitchCompat
│       ├── VSliderFactory.kt       — SeekBar
│       ├── VModalFactory.kt        — Dialog overlay
│       ├── VAlertDialogFactory.kt  — AlertDialog.Builder
│       ├── VProgressBarFactory.kt  — Horizontal ProgressBar
│       ├── VSegmentedControlFactory.kt — RadioGroup
│       ├── VPickerFactory.kt       — DatePicker
│       ├── VActionSheetFactory.kt  — AlertDialog with item list
│       ├── VStatusBarFactory.kt    — WindowInsetsController
│       ├── VWebViewFactory.kt      — WebView
│       ├── VActivityIndicatorFactory.kt — ProgressBar (circular)
│       ├── VSafeAreaFactory.kt     — WindowInsets-aware container
│       └── VKeyboardAvoidingFactory.kt  — Keyboard-aware container
├── Styling/
│   └── StyleEngine.kt        — JS style props → Android View properties
├── Modules/
│   ├── NativeModule.kt       — Interface for all native modules
│   ├── NativeModuleRegistry.kt
│   ├── HapticsModule.kt      — VibrationEffect
│   ├── AsyncStorageModule.kt — SharedPreferences KV store
│   ├── ClipboardModule.kt    — ClipboardManager
│   ├── DeviceInfoModule.kt   — Build info + DisplayMetrics
│   ├── NetworkModule.kt      — ConnectivityManager.NetworkCallback
│   ├── AppStateModule.kt     — ProcessLifecycleOwner
│   ├── LinkingModule.kt      — Intent ACTION_VIEW
│   ├── ShareModule.kt        — Intent ACTION_SEND
│   ├── AnimationModule.kt    — ObjectAnimator
│   ├── KeyboardModule.kt     — InputMethodManager
│   ├── PermissionsModule.kt  — ContextCompat.checkSelfPermission
│   ├── GeolocationModule.kt  — FusedLocationProviderClient
│   ├── NotificationsModule.kt — NotificationCompat + scheduled delivery
│   ├── HttpModule.kt         — OkHttp wrapper for useHttp() composable
│   ├── BiometryModule.kt     — BiometricManager capability check
│   └── CameraModule.kt       — Stub (requires Activity integration)
├── Helpers/
│   └── GestureHelper.kt      — Touch event helpers
├── Tags.kt                   — View tag ID constants
└── VueNativeActivity.kt      — Base Activity for all Vue Native apps
```

## Quick Start

### 1. Add VueNativeCore to your project

In your app's `settings.gradle.kts`:
```kotlin
include(":VueNativeCore")
project(":VueNativeCore").projectDir = File("path/to/VueNativeCore")
```

In your app's `build.gradle.kts`:
```kotlin
dependencies {
    implementation(project(":VueNativeCore"))
}
```

### 2. Create your Activity

```kotlin
class MainActivity : VueNativeActivity() {
    // Path to your compiled Vue bundle in src/main/assets/
    override fun getBundleAssetPath(): String = "vue-native-bundle.js"

    // For hot reload during development (optional)
    // ws://10.0.2.2:5173 connects from emulator to host machine
    override fun getDevServerUrl(): String? = if (BuildConfig.DEBUG) "ws://10.0.2.2:5173" else null
}
```

### 3. Build the Vue bundle

```bash
cd your-vue-native-app
bun run build   # or: npx vite build
```

Copy the output file to `app/src/main/assets/vue-native-bundle.js`.

### 4. Run

Open the Android project in Android Studio and run on an emulator or device.

## Development with Hot Reload

1. Start the Vite dev server:
   ```bash
   bun run dev
   ```

2. Set `getDevServerUrl()` to `"ws://10.0.2.2:5173"` (emulator) or your machine's IP for a real device.

3. The app connects on start and automatically reloads when you save Vue files.

## Thread Model

| Thread | Purpose |
|--------|---------|
| `VueNative-JS` (HandlerThread) | All V8 operations — **never access V8 from other threads** |
| Main Thread | All Android View operations, bridge operation dispatch |
| IO Thread (Coroutines) | HTTP requests, WebSocket, image loading |

## Adding Custom Native Modules

Implement `NativeModule` and register in your subclass of `VueNativeActivity`:

```kotlin
class MyModule : NativeModule {
    override val moduleName = "MyModule"

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "doSomething" -> {
                // ... do work ...
                callback(mapOf("result" to "done"), null)
            }
            else -> callback(null, "Unknown method: $method")
        }
    }
}
```

```kotlin
class MainActivity : VueNativeActivity() {
    override fun getBundleAssetPath() = "bundle.js"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NativeModuleRegistry.getInstance(this).register(MyModule())
    }
}
```

From Vue/TypeScript:
```typescript
import { NativeBridge } from '@thelacanians/runtime'

const result = await NativeBridge.invokeNativeModule('MyModule', 'doSomething', [])
```

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| `com.eclipsesource.j2v8:j2v8` | 6.2.1 | V8 JavaScript engine |
| `com.google.android.flexbox:flexbox` | 3.0.0 | CSS Flexbox layout |
| `io.coil-kt:coil` | 2.7.0 | Async image loading |
| `com.squareup.okhttp3:okhttp` | 4.12.0 | HTTP (fetch polyfill, hot reload) |
| `androidx.recyclerview:recyclerview` | 1.3.2 | VList virtualization |
| `androidx.webkit:webkit` | 1.10.0 | VWebView |
| `androidx.swiperefreshlayout:swiperefreshlayout` | 1.1.0 | VScrollView pull-to-refresh |
| `androidx.biometric:biometric` | 1.1.0 | BiometryModule |
| `com.google.android.gms:play-services-location` | 21.1.0 | GeolocationModule |

## Minimum Requirements

- Android API 21 (Android 5.0 Lollipop)
- Kotlin 1.9+
- Gradle 8.6
- AGP 8.2.2
