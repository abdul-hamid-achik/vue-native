# Hot Reload

Vue Native supports hot reload — edit a `.vue` file and see the change on your device or simulator instantly, without restarting the app.

## How it works

1. `vue-native dev` starts Vite in watch mode and a WebSocket server on port 8174
2. When a file changes, Vite rebuilds the bundle and writes `dist/vue-native-bundle.js`
3. A file watcher detects the change and broadcasts the new bundle over WebSocket
4. `HotReloadManager` on the native side receives the bundle, tears down the current JS context, and re-evaluates the new bundle
5. Vue re-renders from scratch — your app reflects the new code

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

::: tip
Use a real device? Make sure the device and your computer are on the same Wi-Fi network, then use your computer's local IP address (e.g. `ws://192.168.1.5:8174`) instead of `localhost`.
:::
