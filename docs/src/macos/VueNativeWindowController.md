# VueNativeWindowController

`VueNativeWindowController` is the supported `NSWindowController` host for Vue Native apps on macOS. It owns the JavaScript runtime, native bridge, root AppKit view, resize events, and optional hot reload for one window.

## Usage

```swift
import VueNativeMacOS

class MainWindowController: VueNativeWindowController {
    override var bundleName: String { "vue-native-bundle" }

    override var devServerURL: URL? {
        #if DEBUG
        URL(string: "ws://localhost:8174")
        #else
        nil
        #endif
    }
}
```

The inherited convenience initializer creates a resizable 800 × 600 window titled `Vue Native`. Its content view is a `FlippedView`, so layout uses a CSS-compatible top-left origin.

## Public properties

### `bundleName: String`

The name of the JavaScript bundle resource in the application bundle, without the `.js` extension.

Default: `"vue-native-bundle"`

### `devServerURL: URL?`

The WebSocket URL used by the hot-reload client. Return `nil` in production. The embedded bundle remains the deterministic initial bundle and fallback.

Default: `nil`

These are the only window-controller configuration properties currently exposed for overriding. `windowTitle`, `windowSize`, `windowMinSize`, `registerCustomModules()`, and `registerCustomComponents()` are not public `VueNativeWindowController` APIs.

## Window configuration

Configure the inherited `window` before returning the controller from your app delegate:

```swift
import AppKit
import VueNativeMacOS

@main
class AppDelegate: VueNativeAppDelegate {
    override func createWindowController() -> VueNativeWindowController {
        let controller = MainWindowController()
        controller.window?.title = "My App"
        controller.window?.setContentSize(NSSize(width: 1024, height: 768))
        controller.window?.contentMinSize = NSSize(width: 600, height: 400)
        return controller
    }
}
```

This uses only the public controller and `NSWindow` APIs; no framework registry access is required.

## What the controller owns

When the window loads, the controller:

1. Uses the window's `FlippedView` content view as the native root.
2. creates a fresh JavaScriptCore context for the host on the dedicated serial JavaScript queue;
3. initializes `NativeBridge` on the main thread and registers the built-in components and native modules;
4. loads the embedded bundle named by `bundleName`;
5. connects `HotReloadManager` when `devServerURL` is non-nil in a debug build; and
6. publishes the initial dimensions and later window-size changes through the `dimensionsChange` global event.

The initialization order is managed internally. Application code should not separately call `JSRuntime.initialize()`, `NativeBridge.initialize()`, or registry setup when using this controller.

## Lifecycle and threading

- JavaScriptCore runs on a dedicated serial queue, not on the AppKit main thread.
- Bridge view operations and all AppKit work run on the main thread.
- Window resize notifications update `useDimensions()` after the bundle has loaded.
- When the controller is released, it removes its resize observer and releases the bridge/runtime only if it still owns the active host.

Keep a strong reference to the window controller for as long as the window should remain open. `VueNativeAppDelegate` does this through its public `windowController` property.

## Adding native functionality

The macOS native-module and component registries are framework internals; there are no `registerCustomModules()` or `registerCustomComponents()` override hooks on the window controller.

For application-specific native modules, use [Native Blocks](/guide/native-blocks.md), which generates registration code during the build. A public application-level custom-component registration API is not currently available.

## Hot reload

Enable hot reload only for debug builds:

```swift
class MainWindowController: VueNativeWindowController {
    override var devServerURL: URL? {
        #if DEBUG
        URL(string: "ws://localhost:8174")
        #else
        nil
        #endif
    }
}
```

The controller loads the embedded bundle first. Subsequent bundles received from the development server replace the JavaScript context while preserving the native host window.

## See also

- [macOS setup](/macos/setup.md)
- [Native Blocks](/guide/native-blocks.md)
- [Dual-thread architecture](/architecture/dual-thread.md)
