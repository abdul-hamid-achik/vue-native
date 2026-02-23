# Project Structure

```
my-app/
├── app/
│   ├── main.ts          # Entry point — creates and mounts the Vue app
│   ├── App.vue          # Root component
│   └── views/           # Screen components
├── ios/                 # Xcode project
│   ├── Sources/
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift  (or subclass VueNativeViewController)
│   │   └── Info.plist
│   └── project.yml      # XcodeGen project definition
├── android/             # Android Gradle project
│   └── app/
│       └── src/main/
│           ├── kotlin/…/MainActivity.kt  (extends VueNativeActivity)
│           └── AndroidManifest.xml
├── dist/                # Built JS bundle (auto-generated, do not commit)
│   └── vue-native-bundle.js
├── vite.config.ts
└── package.json
```

## Key files

### `app/main.ts`

Creates the Vue app and starts the native renderer:

```ts
import { createApp } from '@thelacanians/vue-native-runtime'
import App from './App.vue'

createApp(App).start()
```

### `vite.config.ts`

```ts
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vue-native-vite-plugin'

export default defineConfig({
  plugins: [vue(), vueNative({ platform: 'ios' })],
})
```

### iOS: `SceneDelegate.swift`

The simplest setup uses `VueNativeViewController`:

```swift
import UIKit
import VueNativeCore

class MyAppViewController: VueNativeViewController {
    override var bundleName: String { "vue-native-bundle" }
    // For hot reload during development:
    // override var devServerURL: URL? { URL(string: "ws://localhost:8174") }
}
```

### Android: `MainActivity.kt`

```kotlin
import com.vuenative.core.VueNativeActivity

class MainActivity : VueNativeActivity() {
    override fun getBundleAssetPath() = "vue-native-bundle.js"
    // For hot reload during development:
    // override fun getDevServerUrl() = "ws://10.0.2.2:8174"
}
```
