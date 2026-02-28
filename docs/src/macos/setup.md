# macOS Setup — Build & Run

This guide walks through every step to get a Vue Native app building and running as a native macOS desktop application.

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| **Xcode** | 16+ | [Mac App Store](https://apps.apple.com/app/xcode/id497799835) |
| **Xcode Command Line Tools** | (bundled) | `xcode-select --install` |
| **Bun** (or Node 18+) | 1.3+ | `curl -fsSL https://bun.sh/install \| bash` |

Verify your environment:

```bash
xcode-select -p          # /Applications/Xcode.app/Contents/Developer
swift --version           # Apple Swift version 6.0+
bun --version             # 1.3+
```

::: tip First-time Xcode install
After installing Xcode, open it once and accept the license.
:::

## Quick start (CLI)

The fastest path — the CLI handles everything:

```bash
# 1. Scaffold project with macOS platform
npx @thelacanians/vue-native-cli create my-mac-app --platforms macos
cd my-mac-app
bun install

# 2. Build JS bundle + run macOS app
vue-native run macos
```

`vue-native run macos` does all of the following automatically:
1. Runs `vite build` to produce `dist/vue-native-bundle.js`
2. Generates the Xcode project from `macos/project.yml` via XcodeGen
3. Builds the app with `xcodebuild`
4. Launches the `.app` bundle

If you want to understand what happens under the hood (or run steps manually), read on.

## Step-by-step (manual)

### 1. Create a new Xcode project

You can either use the CLI scaffold or create the project manually.

**Using the CLI:**

```bash
npx @thelacanians/vue-native-cli create my-mac-app --platforms macos
cd my-mac-app
bun install
```

This generates:

```
my-mac-app/
  app/                 # Vue 3 source
    main.ts
    App.vue
    pages/Home.vue
  macos/               # Native Xcode project
    project.yml        # XcodeGen spec
    Sources/
      Info.plist
      AppDelegate.swift
      MainWindowController.swift
  dist/                # Built JS bundle (generated)
  vite.config.ts
  vue-native.config.ts
  package.json
```

**Creating manually in Xcode:**

1. Open Xcode, select **File > New > Project**
2. Under **macOS**, choose **App**
3. Set the language to **Swift** and interface to **Storyboard** (you will replace the storyboard with code)
4. Create the project

### 2. Add VueNativeMacOS as SPM dependency

In Xcode:

1. Select your project in the navigator
2. Go to **Package Dependencies** tab
3. Click **+** and enter the repository URL:

```
https://github.com/abdul-hamid-achik/vue-native
```

4. Set **Dependency Rule** to **Branch: main**
5. Select the **VueNativeMacOS** library product and add it to your macOS target

Or in `project.yml` (if using XcodeGen):

```yaml
packages:
  VueNativeMacOS:
    url: https://github.com/abdul-hamid-achik/vue-native
    branch: main
targets:
  MyMacApp:
    type: application
    platform: macOS
    deploymentTarget: "15.0"
    dependencies:
      - package: VueNativeMacOS
```

### 3. Create AppDelegate.swift

Replace the generated `AppDelegate.swift` with:

```swift
import Cocoa
import VueNativeMacOS

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: MainWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = MainWindowController()
        windowController.showWindow(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
```

### 4. Create MainWindowController.swift

Create a new file `MainWindowController.swift` that subclasses `VueNativeWindowController`:

```swift
import VueNativeMacOS

class MainWindowController: VueNativeWindowController {
    // Required: name of the JS bundle resource (without extension)
    override var bundleName: String { "vue-native-bundle" }

    // Optional: WebSocket URL for hot reload (development only)
    #if DEBUG
    override var devServerURL: URL? {
        URL(string: "ws://localhost:8174")
    }
    #endif
}
```

### 5. Configure the bundle

Ensure the JS bundle is included in your app target:

**Build the JS bundle:**

```bash
bun run build
```

**Add to Xcode:** Drag `dist/vue-native-bundle.js` into your Xcode project navigator. Make sure **"Copy items if needed"** is checked and the file is added to your macOS target.

Or with a Run Script build phase (recommended):

1. Select your target in Xcode
2. Go to **Build Phases**
3. Click **+** > **New Run Script Phase**
4. Add:

```bash
cp "${SRCROOT}/../dist/vue-native-bundle.js" "${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Resources/"
```

### 6. Build and run

From the command line:

```bash
xcodebuild \
  -project MyMacApp.xcodeproj \
  -scheme MyMacApp \
  -configuration Debug \
  build

# Launch the app
open DerivedData/Build/Products/Debug/MyMacApp.app
```

Or in Xcode: press **Cmd+R**.

::: tip First build is slow
The first build downloads and compiles SPM dependencies (~1-2 min). Subsequent builds are incremental and much faster.
:::

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
vue-native run macos
```

Or build from Xcode. Once the app is running, you don't need to rebuild — changes are pushed via WebSocket.

### How it works

1. You save `app/pages/Home.vue`
2. Vite detects the change, rebuilds `vue-native-bundle.js`
3. The dev server sends the new bundle over WebSocket
4. `HotReloadManager` in the app receives it
5. `JSRuntime` tears down the old JSContext, creates a new one, evaluates the new bundle
6. The window content updates on screen

### Enabling hot reload in your app

The scaffolded project already has hot reload configured via `devServerURL`:

```swift
class MainWindowController: VueNativeWindowController {
    override var bundleName: String { "vue-native-bundle" }

    #if DEBUG
    override var devServerURL: URL? {
        URL(string: "ws://localhost:8174")
    }
    #endif
}
```

Since the macOS app runs on the same machine as the dev server, `localhost` works directly.

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

In debug builds, unhandled JS errors display a red overlay in the window with the error message and stack trace.

### Checking the bundle loaded

If you see an empty window, verify the bundle is executing:

```ts
// Add to the top of app/main.ts
console.log('Bundle executing')
```

If you see the log, the bundle loaded. If not, check:
- The Run Script build phase copies `vue-native-bundle.js` into the `.app` bundle
- The file exists: `bun run build` completed without errors

## Common issues

**"No such module 'VueNativeMacOS'"** — SPM hasn't resolved yet. In Xcode: **File > Packages > Resolve Package Versions**. If that fails, delete `DerivedData`:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

**"Signing requires a development team"** — Open the project in Xcode, select the app target, go to **Signing & Capabilities**, and select your team.

**Empty window** — The most likely cause is the JS bundle not being copied into the app. Rebuild with `bun run build`, then rebuild the native app. Also check the Xcode console for `[VueNative]` errors.

**Coordinate system issues** — AppKit uses a bottom-left origin by default. VueNativeMacOS uses `FlippedView` (an `NSView` subclass with `isFlipped = true`) to provide a top-left origin consistent with iOS and CSS. If you add custom `NSView` subclasses, override `isFlipped` to return `true`.

**Window doesn't appear** — Verify `applicationDidFinishLaunching` creates and shows the window controller. Also check that `applicationShouldTerminateAfterLastWindowClosed` is not causing premature termination.

See the [Troubleshooting](/guide/troubleshooting.md) guide for more.
