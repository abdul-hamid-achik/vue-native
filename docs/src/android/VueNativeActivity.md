# VueNativeActivity

`VueNativeActivity` is the base `AppCompatActivity` for Vue Native apps on Android. Subclass it to get the JS runtime, native bridge, and hot reload wired up automatically.

## Usage

```kotlin
import com.vuenative.core.NativeModule
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

    // Optional: create app-owned modules for this JavaScript world
    override fun createNativeModules(): List<NativeModule> = listOf(MyModule())
}
```

## Methods

### `getBundleAssetPath(): String` (abstract)

Return the path to the JS bundle in your app's `assets/` folder.

### `getDevServerUrl(): String?` (open)

Return the WebSocket URL of the Vite dev server. Return `null` (default) to disable hot reload and load only from assets.

### `createNativeModules(): List<NativeModule>` (protected open)

Return application-specific native modules. The Activity calls this factory at
startup and again for every accepted hot reload, so return **new module
instances on every call**. The previous JavaScript world's modules are
destroyed before their replacements are initialized.

Application modules are registered after the built-in and generated modules.
If an application module uses the same `moduleName` as an earlier module, the
application module intentionally replaces that implementation.

## What it does

`VueNativeActivity` handles:

1. Creates a `FrameLayout` root container that fills the screen
2. Sets up edge-to-edge rendering (draws behind status and navigation bars)
3. Initializes `JSRuntime` (V8 engine, polyfills on `VueNative-JS` thread)
4. Initializes `NativeBridge` with the root container
5. Registers built-in modules, generated modules, then application modules from `createNativeModules()`
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

Pressing the system back button dispatches the `hardware:backPress` global
event. Use `useBackHandler()` to consume it from a component:

```ts
import { useBackHandler } from '@thelacanians/vue-native-runtime'

useBackHandler(() => {
  router.pop()
  return true
})
```

Return `true` after handling the action. Return `false` to run the default
Android back action, which finishes the Activity. If JavaScript has no
`hardware:backPress` listener, `VueNativeActivity` also performs that default
action.
