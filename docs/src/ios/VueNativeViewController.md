# VueNativeViewController

`VueNativeViewController` is the base UIViewController for Vue Native apps on iOS. Subclass it to get the JS runtime, native bridge, and hot reload wired up automatically.

## Usage

```swift
import VueNativeCore

class MyAppViewController: VueNativeViewController {
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

## What it does

`VueNativeViewController` handles:

1. Sets `view.backgroundColor = .systemBackground`
2. Calls `JSRuntime.shared.initialize` — creates the JSContext and registers polyfills
3. Inside the runtime callback, calls `NativeBridge.shared.initialize(rootViewController: self)` — registers `__VN_flushOperations` on the now-existing JSContext
4. Loads the JS bundle from the embedded resource (or dev server)
5. Optionally connects hot reload via `HotReloadManager.shared`

::: warning Init order matters
The bridge **must** be initialized after the runtime creates the JSContext. If `bridge.initialize()` runs first, it tries to register `__VN_flushOperations` on a nil context — the registration is silently dropped, and the app renders a white screen. This was fixed in v0.4.7.
:::

## Manual setup

If you need more control, you can set up the runtime manually without subclassing:

```swift
import VueNativeCore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let rootVC = UIViewController()
        window.rootViewController = rootVC
        window.makeKeyAndVisible()
        self.window = window

        // Runtime MUST initialize first (creates JSContext).
        // Bridge init goes inside the callback so the context exists.
        JSRuntime.shared.initialize {
            NativeBridge.shared.initialize(rootViewController: rootVC)
            DispatchQueue.main.async {
                JSRuntime.shared.loadBundle(source: .embedded(name: "vue-native-bundle")) { _ in }
            }
        }
    }
}
```
