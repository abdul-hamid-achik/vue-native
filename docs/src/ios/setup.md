# iOS Setup — Build & Run on Simulator

This guide walks through every step to get a Vue Native app building and running on the iOS Simulator, from prerequisites to hot reload.

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| **Xcode** | 15+ | [Mac App Store](https://apps.apple.com/app/xcode/id497799835) |
| **Xcode Command Line Tools** | (bundled) | `xcode-select --install` |
| **XcodeGen** | 2.38+ | `brew install xcodegen` |
| **Bun** (or Node 18+) | 1.3+ | `curl -fsSL https://bun.sh/install \| bash` |
| **iOS Simulator** | (bundled) | Included with Xcode |

Verify your environment:

```bash
xcode-select -p          # /Applications/Xcode.app/Contents/Developer
swift --version           # Apple Swift version 5.9+
xcodegen --version        # XcodeGen 2.38+
bun --version             # 1.3+
xcrun simctl list devices # lists available simulators
```

::: tip First-time Xcode install
After installing Xcode, open it once and accept the license. Then install the iOS Simulator runtime: **Xcode > Settings > Platforms > iOS > Download**.
:::

## Quick start (CLI)

The fastest path — the CLI handles everything:

```bash
# 1. Scaffold project
npx @thelacanians/vue-native-cli create my-app
cd my-app
bun install

# 2. Build JS bundle + run on simulator (all-in-one)
vue-native run ios
```

`vue-native run ios` does all of the following automatically:
1. Runs `vite build` to produce `dist/vue-native-bundle.js`
2. Generates the Xcode project from `ios/project.yml` via XcodeGen
3. Builds the app with `xcodebuild`
4. Boots the iOS Simulator
5. Installs and launches the app

If you want to understand what happens under the hood (or run steps manually), read on.

## Step-by-step (manual)

### 1. Create and scaffold

```bash
npx @thelacanians/vue-native-cli create my-app
cd my-app
bun install
```

This generates:

```
my-app/
  app/                 # Vue 3 source
    main.ts
    App.vue
    pages/Home.vue
  ios/                 # Native Xcode project
    project.yml        # XcodeGen spec
    Sources/
      Info.plist
      AppDelegate.swift
      SceneDelegate.swift
  dist/                # Built JS bundle (generated)
  vite.config.ts
  vue-native.config.ts
  package.json
```

### 2. Build the JS bundle

```bash
bun run build
```

This runs Vite with the Vue Native plugin. It:
- Compiles `.vue` SFCs via `@vitejs/plugin-vue`
- Aliases `vue` imports to `@thelacanians/vue-native-runtime` (the native renderer)
- Outputs a single IIFE file: `dist/vue-native-bundle.js`
- Target: ES2020 (JavaScriptCore on iOS 16+ supports this)

### 3. Generate the Xcode project

```bash
cd ios
xcodegen generate
```

This reads `project.yml` and creates `MyApp.xcodeproj`. The project.yml declares:
- **VueNativeCore** as a remote Swift Package dependency (from GitHub)
- A **Run Script** build phase that copies `dist/vue-native-bundle.js` into the `.app` bundle
- Deployment target: iOS 16.0
- Swift 5.9

::: tip
You only need to re-run `xcodegen generate` when you change `project.yml` (e.g. adding a new dependency or build phase). Source code changes don't require it.
:::

### 4. Build the app

From the `ios/` directory:

```bash
xcodebuild \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -configuration Debug \
  build
```

This:
- Resolves Swift Package Manager dependencies (VueNativeCore, FlexLayout)
- Compiles Swift sources (AppDelegate, SceneDelegate)
- Copies the JS bundle into the app via the Run Script phase
- Produces a `.app` in `DerivedData/`

::: tip First build is slow
The first build downloads and compiles SPM dependencies (~1-2 min). Subsequent builds are incremental and much faster.
:::

### 5. Boot the simulator

```bash
# List available simulators
xcrun simctl list devices available

# Boot a specific simulator
xcrun simctl boot "iPhone 16"

# Open the Simulator app
open -a Simulator
```

### 6. Install and launch

```bash
# Find the .app path
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData \
  -name "MyApp.app" -path "*/Debug-iphonesimulator/*" | head -1)

# Install
xcrun simctl install booted "$APP_PATH"

# Launch
xcrun simctl launch booted com.vuenative.myapp
```

Your app should appear on the simulator.

## Using Xcode directly

You can also build and run from Xcode's GUI:

1. Open `ios/MyApp.xcodeproj`
2. Select your scheme (top-left dropdown) and an iPhone simulator
3. Press **Cmd+R** (or **Product > Run**)

Xcode handles the build, install, and launch. The console pane (Cmd+Shift+Y) shows `[VueNative]` log output.

## Hot reload

Hot reload lets you edit `.vue` files and see changes instantly without rebuilding the native app.

### Setup

**Terminal 1 — Start the dev server:**

```bash
bun run dev
```

This starts:
- Vite in watch mode (rebuilds `dist/vue-native-bundle.js` on every save)
- A WebSocket server on `ws://localhost:8174`

**Terminal 2 — Run the app** (first time only):

```bash
vue-native run ios
```

Or build from Xcode. Once the app is running, you don't need to rebuild — changes are pushed via WebSocket.

### How it works

1. You save `app/pages/Home.vue`
2. Vite detects the change, rebuilds `vue-native-bundle.js`
3. The dev server sends the new bundle over WebSocket
4. `HotReloadManager` in the app receives it
5. `JSRuntime` tears down the old JSContext, creates a new one, evaluates the new bundle
6. UI updates on screen

### Enabling hot reload in your app

In the scaffolded project, the SceneDelegate subclasses `VueNativeViewController` which accepts a `devServerURL`:

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

The iOS Simulator shares the host network, so `localhost` works directly.

## Debugging

### Xcode console

All `console.log()` / `console.error()` calls from your Vue code appear in the Xcode console prefixed with `[VueNative JS]`:

```
[VueNative JS] App started
[VueNative JS] Navigated to /settings
```

Bridge operations are logged as:

```
[VueNative] createComponent VView (nodeId: 3)
[VueNative] setProp text="Hello" (nodeId: 5)
```

### Error overlay

In debug builds, unhandled JS errors display a red overlay on screen with the error message and stack trace.

### Checking the bundle loaded

If you see a white screen, verify the bundle is executing:

```ts
// Add to the top of app/main.ts
console.log('Bundle executing')
```

If you see the log, the bundle loaded. If not, check:
- The Run Script build phase copies `vue-native-bundle.js` into the app bundle
- The file exists: `bun run build` completed without errors

### Useful simulator commands

```bash
# Take a screenshot
xcrun simctl io booted screenshot ~/Desktop/screenshot.png

# Open a URL (deep linking)
xcrun simctl openurl booted "myapp://settings"

# Reset simulator state
xcrun simctl erase "iPhone 16"

# View app container (logs, data)
xcrun simctl get_app_container booted com.vuenative.myapp data
```

## Common issues

**"No such module 'VueNativeCore'"** — SPM hasn't resolved yet. In Xcode: **File > Packages > Resolve Package Versions**. If that fails, delete `DerivedData`:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

**"Signing requires a development team"** — Open the project in Xcode, select the app target, go to **Signing & Capabilities**, and select your team (a free Apple ID works for simulator builds).

**White screen** — The most likely cause is the JS bundle not being copied into the app. Rebuild with `bun run build`, then rebuild the native app. Also check the Xcode console for `[VueNative]` errors.

**Simulator won't boot** — Reset it:

```bash
xcrun simctl shutdown all
xcrun simctl erase all
```

**"Cannot find 'FlexLayout' in scope"** — The FlexLayout SPM dependency failed to resolve. Delete `DerivedData` and the SPM cache, then rebuild:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/org.swift.swiftpm
```

See the [Troubleshooting](/guide/troubleshooting.md) guide for more.
