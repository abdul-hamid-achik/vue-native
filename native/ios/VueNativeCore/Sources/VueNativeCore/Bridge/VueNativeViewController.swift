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
    private let hostID = UUID()
    private var lastDimensions: (width: CGFloat, height: CGFloat, scale: CGFloat)?
    private var hasLoadedBundle = false

    // MARK: - Lifecycle

    override open func viewDidLoad() {
        super.viewDidLoad()
        // Use black as the loading background so any unstyled gap between the
        // native chrome and the Vue-rendered root view is not visible.
        // The Vue app sets its own background colour via VSafeArea / VView props.
        view.backgroundColor = .black

        // Initialize JS engine first (creates JSContext, registers polyfills).
        // Bridge init MUST happen inside this callback so the JSContext exists
        // when __VN_flushOperations is registered. Calling bridge.initialize()
        // before this creates a nil-context registration that silently drops,
        // causing a white screen.
        runtime.initializeForHost { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.bridge.initialize(rootViewController: self, hostID: self.hostID)
                self.loadBundle()
            }
        }
    }

    /// Keep useDimensions() in sync with rotation, Split View, and other
    /// window-size changes. The bridge serializes this payload back to the JS
    /// queue, so this method remains UI-thread-only.
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        emitDimensionsIfNeeded()
    }

    private func emitDimensionsIfNeeded() {

        guard hasLoadedBundle else { return }
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let scale = view.window?.screen.scale ?? UIScreen.main.scale
        let dimensions = (width: size.width, height: size.height, scale: scale)

        if let previous = lastDimensions,
           previous.width == dimensions.width,
           previous.height == dimensions.height,
           previous.scale == dimensions.scale {
            return
        }

        lastDimensions = dimensions
        bridge.dispatchGlobalEvent(
            "dimensionsChange",
            payload: [
                "width": dimensions.width,
                "height": dimensions.height,
                "scale": dimensions.scale,
            ]
        )
    }

    // MARK: - Bundle loading

    private func loadBundle() {
        #if DEBUG
        if let wsURL = devServerURL {
            // Connect hot reload manager; it will also do the initial HTTP fetch
            HotReloadManager.shared.connect(to: wsURL)
            // Development builds keep their deterministic embedded fallback;
            // an applied OTA bundle must never race the live-reload source.
            loadEmbeddedBundle()
            return
        }
        #endif

        if let otaURL = OTAModule.activeBundleURL() {
            loadOTABundle(at: otaURL)
        } else {
            loadEmbeddedBundle()
        }
    }

    private func loadOTABundle(at url: URL) {
        runtime.loadBundle(source: .file(url: url)) { [weak self] success in
            guard let self else { return }
            if success {
                DispatchQueue.main.async {
                    self.hasLoadedBundle = true
                    self.emitDimensionsIfNeeded()
                }
                NSLog("[VueNative] Loaded verified OTA bundle '%@'", url.lastPathComponent)
                return
            }

            // The file was verified before selection but may have disappeared or
            // become unreadable, or JavaScriptCore may reject it during
            // evaluation. A failed bundle can already have mutated globals and
            // queued work, so discard the entire JavaScript world before loading
            // the embedded app-store bundle.
            self.runtime.recreate { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async {
                    OTAModule.invalidateActiveBundle()
                    self.bridge.reset()
                    self.bridge.initialize(rootViewController: self, hostID: self.hostID)
                    NSLog("[VueNative] OTA bundle failed to load; falling back to embedded bundle in a fresh context")
                    self.loadEmbeddedBundle()
                }
            }
        }
    }

    private func loadEmbeddedBundle() {
        runtime.loadBundle(source: .embedded(name: bundleName)) { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }
                self.hasLoadedBundle = success
                if success {
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded()
                    self.emitDimensionsIfNeeded()
                }
            }
            if !success {
                NSLog("[VueNative] ERROR: Failed to load bundle '%@'", self?.bundleName ?? "unknown")
            }
        }
    }

    deinit {
        let hostID = hostID
        Task { @MainActor in
            let bridge = NativeBridge.shared
            if bridge.releaseHost(hostID: hostID) {
                JSRuntime.shared.invalidate()
            }
        }
    }
}
#endif
