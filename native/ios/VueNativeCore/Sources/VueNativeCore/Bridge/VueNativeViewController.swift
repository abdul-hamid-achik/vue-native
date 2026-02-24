#if canImport(UIKit)
import UIKit

// MARK: - VueNativeViewController

/// Base view controller for all Vue Native apps.
///
/// Subclass this and override ``bundleName`` to point at your JS bundle.
/// Optionally override ``devServerURL`` to enable hot reload during development.
///
/// ```swift
/// // SceneDelegate.swift
/// class SceneDelegate: UIResponder, UIWindowSceneDelegate {
///     var window: UIWindow?
///     func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
///                options connectionOptions: UIScene.ConnectionOptions) {
///         guard let windowScene = scene as? UIWindowScene else { return }
///         let window = UIWindow(windowScene: windowScene)
///         window.rootViewController = MyAppViewController()
///         window.makeKeyAndVisible()
///         self.window = window
///     }
/// }
///
/// // MyAppViewController.swift
/// class MyAppViewController: VueNativeViewController {
///     override var bundleName: String { "vue-native-bundle" }
/// }
/// ```
open class VueNativeViewController: UIViewController {

    // MARK: - Overridable API

    /// Name of the JS bundle resource (without extension) bundled in your app target.
    /// Defaults to `"vue-native-bundle"`.
    open var bundleName: String { "vue-native-bundle" }

    /// WebSocket URL of the Vite dev server for hot reload.
    /// Return `nil` (the default) to disable hot reload and load only from the bundle.
    ///
    /// Example: `URL(string: "ws://localhost:8174")`
    open var devServerURL: URL? { nil }

    // MARK: - Private state

    private let runtime = JSRuntime.shared
    private let bridge  = NativeBridge.shared

    // MARK: - Lifecycle

    override open func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Initialize JS engine first (creates JSContext, registers polyfills).
        // Bridge init MUST happen inside this callback so the JSContext exists
        // when __VN_flushOperations is registered. Calling bridge.initialize()
        // before this creates a nil-context registration that silently drops,
        // causing a white screen.
        runtime.initialize { [weak self] in
            guard let self else { return }
            self.bridge.initialize(rootViewController: self)
            DispatchQueue.main.async {
                self.loadBundle()
            }
        }
    }

    // MARK: - Bundle loading

    private func loadBundle() {
        if let wsURL = devServerURL {
            // Connect hot reload manager; it will also do the initial HTTP fetch
            HotReloadManager.shared.connect(to: wsURL)
            // Also load from the embedded bundle immediately as a fallback
            loadEmbeddedBundle()
        } else {
            loadEmbeddedBundle()
        }
    }

    private func loadEmbeddedBundle() {
        runtime.loadBundle(source: .embedded(name: bundleName)) { success in
            if !success {
                NSLog("[VueNative] ERROR: Failed to load bundle '%@'", self.bundleName)
            }
        }
    }
}
#endif
