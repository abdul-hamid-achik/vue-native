# Hot Reload

Vue Native supports hot reload — edit a `.vue` file and see the change on your device or simulator instantly, without restarting the app.

## How it works

1. `vue-native dev` starts Vite in watch mode and a WebSocket server on port 8174
2. When a file changes, Vite rebuilds the bundle and writes `dist/vue-native-bundle.js`
3. A file watcher detects the change and broadcasts the new bundle over WebSocket
4. `HotReloadManager` on the native side receives the bundle, tears down the current JS context, and re-evaluates the new bundle
5. Vue re-renders from scratch — your app reflects the new code

::: warning State is reset on reload
Hot reload performs a **full reload** — the entire JS context is torn down and re-created. This means:
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
bun run dev
```

Then run the app from Xcode / Android Studio.

::: tip Physical Devices
The dev server accepts connections from any device on your local network. When you run `vue-native dev`, it prints your LAN IP address:

```
  Hot reload server: ws://localhost:8174
  LAN address:       ws://192.168.1.5:8174
```

Use the LAN address in your device's dev server URL configuration. Both the device and your computer must be on the same Wi-Fi network.
:::
