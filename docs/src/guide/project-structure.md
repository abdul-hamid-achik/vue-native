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
├── macos/               # macOS Xcode project
│   ├── Sources/
│   │   ├── main.swift
│   │   ├── AppDelegate.swift           (subclasses VueNativeAppDelegate)
│   │   ├── MainWindowController.swift  (subclasses VueNativeWindowController)
│   │   ├── Info.plist
│   │   └── App.entitlements
│   └── project.yml      # XcodeGen project definition
├── native/              # Vendored Vue Native runtime, copied by the CLI
│   ├── ios/VueNativeCore/
│   ├── android/VueNativeCore/
│   ├── macos/VueNativeMacOS/
│   └── shared/VueNativeShared/
├── dist/                # Built JS bundle (auto-generated, do not commit)
│   └── vue-native-bundle.js
├── vite.config.ts
└── package.json
```

The generated `ios/*.xcodeproj` and `macos/*.xcodeproj` are gitignored — each `project.yml` is the committed source of truth and XcodeGen recreates the project on demand (`brew install xcodegen`).

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
  plugins: [vue(), vueNative()],
})
```

The CLI passes the selected `run`, `build`, or targeted `dev` platform through `VUE_NATIVE_PLATFORM`. That target overrides the plugin option. An explicit `platform` still acts as the target for direct Vite commands and untargeted `vue-native dev` when the environment variable is absent.

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
