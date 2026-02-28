# VueNativeWindowController

`VueNativeWindowController` is the base `NSWindowController` for Vue Native apps on macOS. Subclass it to get the JS runtime, native bridge, and hot reload wired up automatically.

## Usage

```swift
import VueNativeMacOS

class MainWindowController: VueNativeWindowController {
    // Required: name of the JS bundle resource (without extension)
    override var bundleName: String { "vue-native-bundle" }

    // Optional: WebSocket URL for hot reload (development only)
    override var devServerURL: URL? {
        #if DEBUG
        return URL(string: "ws://localhost:8174")
        #else
        return nil
        #endif
    }
}
```

## Properties

### `bundleName: String`

The name of the JS bundle resource bundled in your app target (without `.js` extension).

Default: `"vue-native-bundle"`

### `devServerURL: URL?`

WebSocket URL of the Vite dev server. When non-nil, `HotReloadManager` connects and listens for bundle updates. The embedded bundle is still loaded as an initial fallback.

Default: `nil`

### `windowTitle: String`

The title displayed in the window title bar.

Default: `"Vue Native"`

### `windowSize: NSSize`

The initial size of the window.

Default: `NSSize(width: 800, height: 600)`

### `windowMinSize: NSSize`

The minimum size the window can be resized to.

Default: `NSSize(width: 400, height: 300)`

## What it does

`VueNativeWindowController` handles:

1. Creates an `NSWindow` with the configured title, size, and style mask
2. Sets the window's `contentView` to a `FlippedView` (top-left origin for CSS-consistent layout)
3. Calls `JSRuntime.shared.initialize` — creates the JSContext and registers polyfills
4. Inside the runtime callback, calls `NativeBridge.shared.initialize(rootView:)` — registers `__VN_flushOperations` on the now-existing JSContext
5. Loads the JS bundle from the embedded resource (or dev server)
6. Optionally connects hot reload via `HotReloadManager.shared`

::: warning Init order matters
The bridge **must** be initialized after the runtime creates the JSContext. If `bridge.initialize()` runs first, it tries to register `__VN_flushOperations` on a nil context — the registration is silently dropped, and the window renders empty. This follows the same pattern as `VueNativeViewController` on iOS.
:::

## Customization

### Custom window configuration

Override properties to customize the window:

```swift
class MainWindowController: VueNativeWindowController {
    override var bundleName: String { "vue-native-bundle" }
    override var windowTitle: String { "My App" }
    override var windowSize: NSSize { NSSize(width: 1024, height: 768) }
    override var windowMinSize: NSSize { NSSize(width: 600, height: 400) }
}
```

### Registering custom native modules

Override `registerCustomModules()` to register additional native modules before the JS bundle loads:

```swift
class MainWindowController: VueNativeWindowController {
    override var bundleName: String { "vue-native-bundle" }

    override func registerCustomModules() {
        NativeModuleRegistry.shared.register("MyModule", module: MyCustomModule())
    }
}
```

### Registering custom components

Override `registerCustomComponents()` to register additional native component factories:

```swift
class MainWindowController: VueNativeWindowController {
    override var bundleName: String { "vue-native-bundle" }

    override func registerCustomComponents() {
        NativeComponentRegistry.shared.register("MyWidget") { props in
            MyWidgetFactory(props: props)
        }
    }
}
```

## Manual setup

If you need more control, you can set up the runtime manually without subclassing:

```swift
import VueNativeMacOS

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "My App"

        let rootView = FlippedView()
        window.contentView = rootView

        // Runtime MUST initialize first (creates JSContext).
        // Bridge init goes inside the callback so the context exists.
        JSRuntime.shared.initialize {
            NativeBridge.shared.initialize(rootView: rootView)
            DispatchQueue.main.async {
                JSRuntime.shared.loadBundle(
                    source: .embedded(name: "vue-native-bundle")
                ) { _ in }
            }
        }

        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
```

## Lifecycle

The window controller manages the following lifecycle:

1. **`windowDidLoad()`** — Configures the window and starts the runtime
2. **`windowWillClose(_:)`** — Tears down the JS runtime and disconnects hot reload
3. **`windowDidResize(_:)`** — Triggers a Yoga layout pass on the root view

The JS runtime runs on the main thread for macOS (unlike iOS where it uses a dedicated serial queue), since macOS apps are less constrained by main thread performance.
