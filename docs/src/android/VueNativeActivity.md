# VueNativeActivity

`VueNativeActivity` is the base `AppCompatActivity` for Vue Native apps on Android. Subclass it to get the JS runtime, native bridge, and hot reload wired up automatically.

## Usage

```kotlin
import com.vuenative.core.VueNativeActivity

class MainActivity : VueNativeActivity() {
    // Required: path to the JS bundle in the app's assets folder
    override fun getBundleAssetPath() = "vue-native-bundle.js"

    // Optional: WebSocket URL for hot reload (development only)
    override fun getDevServerUrl(): String? {
        return if (BuildConfig.DEBUG) {
            // 10.0.2.2 = host machine from Android emulator
            // Use your computer's local IP for a real device
            "ws://10.0.2.2:8174"
        } else null
    }
}
```

## Methods

### `getBundleAssetPath(): String` (abstract)

Return the path to the JS bundle in your app's `assets/` folder.

### `getDevServerUrl(): String?` (open)

Return the WebSocket URL of the Vite dev server. Return `null` (default) to disable hot reload and load only from assets.

## What it does

`VueNativeActivity` handles:

1. Creates a `FrameLayout` root container that fills the screen
2. Sets up edge-to-edge rendering (draws behind status and navigation bars)
3. Initializes `JSRuntime` (V8 engine, polyfills on `VueNative-JS` thread)
4. Initializes `NativeBridge` with the root container
5. Registers all native modules
6. Wires up `__VN_resolveCallback` and `__VN_handleEvent` routing
7. Loads the JS bundle from assets (or connects hot reload)

## Permissions

`VueNativeActivity` implements `onRequestPermissionsResult` and forwards it to `PermissionsModule`. If you override this method, call `super` first:

```kotlin
override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    // your code
}
```

## Back button

By default, pressing the back button dispatches an `android:back` global event to JS. Handle it in your Vue app:

```ts
import { onGlobalEvent } from '@thelacanians/runtime'

onGlobalEvent('android:back', () => {
  router.pop()
})
```
