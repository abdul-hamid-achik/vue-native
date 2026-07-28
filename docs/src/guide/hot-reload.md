# Hot Reload

Vue Native supports hot reload — edit a `.vue` file and see the change on your device or simulator instantly, without restarting the app.

## How it works

1. `vue-native dev` starts Vite in watch mode and a WebSocket server on port 8174
2. When a file changes, Vite rebuilds the bundle and writes `dist/vue-native-bundle.js`
3. A file watcher detects the change and broadcasts the new bundle over WebSocket
4. `HotReloadManager` on the native side receives the bundle and resets the current application world. iOS and macOS recreate JavaScriptCore; Android tears down Vue and polyfill/native state before evaluating in its existing V8 isolate
5. Vue re-renders from scratch — your app reflects the new code

::: warning State is reset on reload
Hot reload performs a **full application reload**. Apple targets recreate the JS context; Android resets the rendered app, bridge registries, timers, animation frames, and Vue state inside the current V8 isolate. In every case:
- All component state (`ref`, `reactive`) is lost
- Navigation stack resets to the initial route
- Pinia/store state is cleared
- Timers, WebSocket connections, and subscriptions are cleaned up and restarted

This is different from Vite's HMR in web apps, which preserves component state. Granular state-preserving HMR is planned for a future release.

**Workaround:** Use `useAsyncStorage` to persist critical state during development, or structure your development workflow to work from the initial screen.
:::

## Setup

### iOS

In your `VueNativeViewController` subclass, return the dev server URL:

```swift
class MyAppViewController: VueNativeViewController {
    override var bundleName: String { "vue-native-bundle" }

    #if DEBUG
    override var devServerURL: URL? {
        URL(string: "ws://localhost:8174")
    }
    #endif
}
```

### Android

In your `VueNativeActivity` subclass:

```kotlin
class MainActivity : VueNativeActivity() {
    override fun getBundleAssetPath() = "vue-native-bundle.js"

    override fun getDevServerUrl(): String? {
        return if (BuildConfig.DEBUG) {
            // 10.0.2.2 is the host machine from the Android emulator
            "ws://10.0.2.2:8174"
        } else null
    }
}
```

## Start development

```bash
vue-native dev --ios
# or: vue-native dev --android
# or: vue-native dev --platform macos
```

Then run the app from Xcode / Android Studio.

The watcher compiles one platform-specific bundle at a time. Use `vue-native dev --ios`, `vue-native dev --android`, or `vue-native dev --platform macos` to select it. Start a new watcher when switching platforms; a single `--ios --android` command is rejected.

::: tip Physical Devices
By default the dev server binds to **localhost only**, so simulators and emulators
(which share the host loopback) connect directly but other devices on your network
cannot. This is the safe default — the dev server can replace your app's JS bundle,
which runs with full native-module privileges.

To develop on a physical device over Wi-Fi, opt in with `--lan`:

```bash
vue-native dev --ios --lan
```

This exposes the server to your local network and prints the LAN address:

```
  Hot reload server: ws://localhost:8174
  LAN address:       ws://192.168.1.5:8174
```

Use the LAN address in your device's dev server URL configuration. Both the device
and your computer must be on the same Wi-Fi network.

**Authentication:** when `--lan` is used, the dev server requires a shared hot-reload
token so a rogue client on your network cannot inject a bundle. The Vite plugin embeds
this token in your bundle (`__HOT_RELOAD_TOKEN__`, persisted under
`node_modules/.vue-native/hot-reload-token`) and the native runtime presents it
automatically when connecting — no manual setup is needed. Connections without a valid
token are rejected.
:::
