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

    // For hot reload during development (optional).
    // Prefer putting this override in src/debug only — see "Development with
    // Hot Reload" below. VueNativeActivity ignores it entirely in a
    // non-debuggable build.
    override fun getDevServerUrl(): String? = if (BuildConfig.DEBUG) "ws://10.0.2.2:8174" else null
}
```

And declare it in your `AndroidManifest.xml` with **both** attributes below:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:configChanges="orientation|screenSize|screenLayout|keyboardHidden|keyboard|locale|layoutDirection|fontScale|uiMode|density"
    android:windowSoftInputMode="adjustResize">
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>
</activity>
```

- **`configChanges` is required.** Without it Android recreates the Activity on
  rotation, dark-mode switch, locale change and font-scale change — which
  destroys the V8 isolate and wipes *all* JS state (component state, stores,
  in-flight promises, navigation stack). The app visibly restarts at its root
  route. `vue-native create` writes this list for you.
- **`windowSoftInputMode="adjustResize"`** is what the Activity's IME-inset
  handling and `VKeyboardAvoiding` rely on.

### 3. Declare the permissions your app uses

See [Permissions](#permissions-host-provided) below — VueNativeCore no longer
merges dangerous permissions into your manifest.

### 4. Build the Vue bundle

```bash
cd your-vue-native-app
bun run build   # or: npx vite build
```

Copy the output file to `app/src/main/assets/vue-native-bundle.js`.

### 5. Run

Open the Android project in Android Studio and run on an emulator or device.

## Permissions (host-provided)

**Breaking change.** `VueNativeCore/src/main/AndroidManifest.xml` used to inject
15 permissions into *every* consumer app — CAMERA, fine/coarse location,
read/write contacts, read/write calendar, POST_NOTIFICATIONS, media and external
storage. All of those are dangerous runtime permissions, so a to-do app built on
Vue Native was declaring camera, contacts, calendar and location access in its
Play Console data-safety form without using any of them.

The library now declares only permissions that are protection level `normal`
(no runtime prompt, no data-safety entry) **and** required by a module that
cannot work without them:

| Declared by the library | Used by |
|---|---|
| `INTERNET` | fetch polyfill, `HttpModule`, `WebSocketModule`, hot reload, `OTAModule` |
| `ACCESS_NETWORK_STATE` | `NetworkModule` |
| `VIBRATE` | `HapticsModule` |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | `BiometryModule` |
| `com.android.vending.BILLING` | `IAPModule` |

Everything else is **yours to declare**. Copy only what you use into your own
`app/src/main/AndroidManifest.xml` (the full snippet is also commented at the
bottom of the library manifest):

```xml
<!-- CameraModule: launchCamera / captureVideo / scanQRCode, VCamera -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />

<!-- AudioModule recording, PermissionsModule "microphone" -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />

<!-- GeolocationModule, PermissionsModule "location" / "locationAlways" -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- ContactsModule / CalendarModule -->
<uses-permission android:name="android.permission.READ_CONTACTS" />
<uses-permission android:name="android.permission.WRITE_CONTACTS" />
<uses-permission android:name="android.permission.READ_CALENDAR" />
<uses-permission android:name="android.permission.WRITE_CALENDAR" />

<!-- NotificationsModule (API 33+; without it POST is silently denied) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- ImagePickerModule / media access -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />

<!-- BluetoothModule (API 31+; without these every call reports unauthorized) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
```

Runtime *requests* are unchanged — they still go through
`PermissionsModule.request()` / `usePermissions()`. Only the manifest entry
moved. Two side effects worth knowing:

- `CameraModule.launchCamera()` / `captureVideo()` fire an
  `ACTION_IMAGE_CAPTURE` intent at the system camera app. Android only requires
  the `CAMERA` permission to be *held* if your app declares it, so hosts that
  never declare `CAMERA` now get system-camera capture working without a
  permission prompt. `Camera.scanQRCode()` uses the in-process CameraX preview
  and still needs `CAMERA`.
- Android Lint can no longer see these permissions when analysing the library,
  so the guarded call sites in `GeolocationModule`, `NotificationsModule` and
  `BluetoothModule` carry an explicit `@Suppress("MissingPermission")` with a
  comment pointing at the runtime check.

### Deep links and `Linking.canOpenURL`

Since Android 11 (API 30), `PackageManager` queries only see packages declared
in a `<queries>` block, so `canOpenURL()` used to return `false` for URLs the
device could open. The library manifest declares `<queries>` for `http`,
`https`, `mailto` and `tel`. For your own schemes, either add an `<intent>`
block to your manifest (`<queries>` entries merge) or register them
programmatically:

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        LinkingModule.registerOpenableSchemes("myapp", "whatsapp")
    }
}
```

`registerOpenableSchemes` makes `canOpenURL` answer `true` for those schemes
without querying the PackageManager, so only register ones you know the device
can handle.

## Development with Hot Reload

1. Start the Vite dev server:
   ```bash
   vue-native dev --android
   ```

2. Set `getDevServerUrl()` to `"ws://10.0.2.2:8174"` (emulator) or your machine's IP for a real device.

3. The app connects on start and automatically reloads when you save Vue files.

Hot reload opens a **plaintext** `ws://` socket and evaluates whatever
JavaScript arrives on it with full native-module privileges, so
`VueNativeActivity` only connects when *both* hold:

- the app is debuggable (`ApplicationInfo.FLAG_DEBUGGABLE`) — the same flag
  `ErrorOverlayView` and `HotReloadStatusView` already gate on, and the
  equivalent of iOS's `#if DEBUG`; and
- the URL host is loopback, link-local or RFC1918-private (`DevServerPolicy`).
  Hostnames are allowed with a warning; a public IP literal is refused.

Otherwise the embedded or verified OTA bundle is loaded instead and the reason
is logged under the `VueNativeActivity` tag.

Keep the override out of release builds entirely by splitting it per source set
(this is what `app/` in this repo does):

```
app/src/debug/kotlin/.../DevServer.kt    →  object DevServer { val url: String? = "ws://10.0.2.2:8174" }
app/src/release/kotlin/.../DevServer.kt  →  object DevServer { val url: String? = null }
app/src/main/kotlin/.../MainActivity.kt  →  override fun getDevServerUrl() = DevServer.url
```

Likewise, keep the cleartext-permitting `network_security_config.xml` in
`src/debug/res/xml/` and a `cleartextTrafficPermitted="false"` base config in
`src/main/res/xml/`, so a release build cannot talk to the dev server even if a
URL slips through.

## Thread Model

| Thread | Purpose |
|--------|---------|
| `VueNative-JS` (HandlerThread) | All V8 operations — **never access V8 from other threads** |
| Main Thread | All Android View operations, bridge operation dispatch |
| IO Thread (Coroutines) | HTTP requests, WebSocket, image loading |

## Adding Custom Native Modules

Implement `NativeModule` and return it from your `VueNativeActivity` factory:

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

    override fun createNativeModules(): List<NativeModule> = listOf(MyModule())
}
```

`createNativeModules()` is called at startup and for every accepted hot reload. Its
returned modules are registered after the built-in and generated modules. Return new
instances on every call so the old JavaScript world's modules can be destroyed before
their replacements are initialized. An application module with the same `moduleName`
intentionally replaces the default.

From Vue/TypeScript:
```typescript
import { NativeBridge } from '@thelacanians/vue-native-runtime'

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

Dependency versions live in `gradle/libs.versions.toml` (single source of truth
for `:VueNativeCore` and `:app`). Two deliberate exceptions: J2V8 stays inline in
`VueNativeCore/build.gradle.kts` because its `@aar` artifact-only notation
cannot be expressed in a catalog and because a V8 engine swap needs full device
re-verification; plugin versions stay in the root `build.gradle.kts`.

`android.suppressUnsupportedCompileSdk=35` in `gradle.properties` is intentional:
AGP 8.2.2 does not officially support compileSdk 35, and bumping AGP drags
Gradle, Kotlin and CameraX along with it. `android.enableJetifier` was removed —
every dependency here is AndroidX already, so it only slowed configuration.

## Quality gates

```bash
cd native/android
./gradlew :VueNativeCore:compileDebugKotlin   # compile
./gradlew :VueNativeCore:testDebugUnitTest    # JUnit + Robolectric (also runs lintDebug)
./gradlew :VueNativeCore:ktlintCheck          # formatting
./gradlew :VueNativeCore:lintDebug            # Android Lint
```

Android Lint runs with `abortOnError = true`. It used to be `false`, which is
why a `NewApi` violation (`ConnectivityManager.getActiveNetwork()`, API 23, with
`minSdk = 21`) shipped in `NetworkModule` — and CI never invoked lint at all.
`testDebugUnitTest` now depends on `lintDebug` so the documented gate is the one
that fails; skip it locally with `-x lintDebug`.

Findings that predate the change are recorded in
`VueNativeCore/lint-baseline.xml` (1 error — `AppCompatCustomView` on
`VTextNodeView` — and 54 warnings). Regenerate with
`./gradlew :VueNativeCore:updateLintBaseline`. **Do not add a `NewApi` entry to
the baseline**; add an `SDK_INT` guard instead.
