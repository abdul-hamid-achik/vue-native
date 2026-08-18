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

    private struct ViewDimensions: Equatable {
        let width: CGFloat
        let height: CGFloat
        let scale: CGFloat
    }

    // MARK: - Overridable API

    /// Name of the JS bundle resource (without extension) bundled in your app target.
    /// Defaults to `"vue-native-bundle"`.
    open var bundleName: String { "vue-native-bundle" }

    /// Test hook: load this file instead of the embedded app resource.
    /// Production hosts leave this `nil`.
    open var fixtureBundleURL: URL? { nil }

    /// WebSocket URL of the Vite dev server for hot reload.
    /// Return `nil` (the default) to disable hot reload and load only from the bundle.
    ///
    /// Example: `URL(string: "ws://localhost:8174")`
    open var devServerURL: URL? { nil }

    // MARK: - Custom component registration

    /// Register a custom component factory under a component type name.
    ///
    /// This is the escape hatch that lets a host application render native
    /// components the framework does not ship with. Once registered, a
    /// `createNativeComponent('Foo')` call on the JS side (i.e. a `<Foo>`
    /// element in a Vue SFC) is created through `factory` by the bridge like
    /// any built-in component. Replaces any factory previously registered for
    /// `name`.
    ///
    /// Registration is process-wide and must happen on the main thread, ideally
    /// before the JS bundle mounts (for example in `viewDidLoad` before calling
    /// `super`, or at app launch).
    ///
    /// ```swift
    /// final class MapFactory: NativeComponentFactory {
    ///     func createView() -> UIView { MKMapView() }
    ///     func updateProp(view: UIView, key: String, value: Any?) { /* ... */ }
    ///     func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) { /* ... */ }
    /// }
    ///
    /// VueNativeViewController.registerComponent("VMap", factory: MapFactory())
    /// ```
    @MainActor
    public static func registerComponent(_ name: String, factory: NativeComponentFactory) {
        ComponentRegistry.shared.register(name, factory: factory)
    }

    // MARK: - Private state

    private let runtime = JSRuntime.shared
    private let bridge  = NativeBridge.shared
    private let hostID = UUID()
    private var lastDimensions: ViewDimensions?
    private var hasLoadedBundle = false
    private var swipeBackGesture: UIScreenEdgePanGestureRecognizer?
    #if DEBUG
    /// Bottom-right connection-status badge, installed only when a dev server
    /// is configured. `nil` otherwise (production apps never allocate it).
    private var hotReloadStatusView: HotReloadStatusView?
    #endif

    // MARK: - Swipe-back gesture thresholds

    /// Minimum horizontal translation (in points) that completes a swipe-back.
    static let swipeBackTranslationThreshold: CGFloat = 80

    /// Fraction of the view width whose horizontal translation also completes a
    /// swipe-back, whichever threshold is reached first.
    static let swipeBackWidthFractionThreshold: CGFloat = 0.5

    // MARK: - Lifecycle

    override open func viewDidLoad() {
        super.viewDidLoad()
        // Use black as the loading background so any unstyled gap between the
        // native chrome and the Vue-rendered root view is not visible.
        // The Vue app sets its own background colour via VSafeArea / VView props.
        view.backgroundColor = .black

        installSwipeBackGesture()
        installErrorReloadHandler()
        #if DEBUG
        installHotReloadStatusIndicator()
        #endif

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
        let dimensions = ViewDimensions(width: size.width, height: size.height, scale: scale)

        if lastDimensions == dimensions {
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

    // MARK: - Swipe-back gesture

    /// Install a left-screen-edge pan gesture that dispatches a global
    /// `gesture:swipeBack` event to JS so the navigation router can pop.
    ///
    /// Because it is a `UIScreenEdgePanGestureRecognizer`, it only recognizes
    /// pans that begin at the extreme left edge of the screen, so it does not
    /// compete with horizontal scrolls or text inputs in the content area.
    private func installSwipeBackGesture() {
        guard swipeBackGesture == nil else { return }
        let gesture = makeSwipeBackGesture()
        view.addGestureRecognizer(gesture)
        swipeBackGesture = gesture
    }

    /// Create and configure the swipe-back recognizer. Exposed internally so it
    /// can be unit-tested without driving the full view-controller lifecycle.
    func makeSwipeBackGesture() -> UIScreenEdgePanGestureRecognizer {
        let gesture = UIScreenEdgePanGestureRecognizer(
            target: self,
            action: #selector(handleSwipeBack(_:))
        )
        gesture.edges = .left
        return gesture
    }

    /// Decide whether a completed edge pan should trigger a swipe-back.
    /// Exposed internally for unit testing.
    static func shouldTriggerSwipeBack(translationX: CGFloat, viewWidth: CGFloat) -> Bool {
        return translationX > swipeBackTranslationThreshold
            || translationX > viewWidth * swipeBackWidthFractionThreshold
    }

    @objc private func handleSwipeBack(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let translation = gesture.translation(in: gesture.view)
        let viewWidth = gesture.view?.bounds.width ?? 0
        guard Self.shouldTriggerSwipeBack(translationX: translation.x, viewWidth: viewWidth) else { return }
        bridge.dispatchGlobalEvent("gesture:swipeBack", payload: [:])
    }

    // MARK: - Hot reload URL

    /// Build the hot reload WebSocket URL, appending `?token=<token>` when a
    /// non-empty token is present.
    ///
    /// The token is injected into the bundle by the vite-plugin and validated
    /// by the dev server only in `--lan` mode. When the token is empty the
    /// base URL is returned unchanged, preserving the existing token-less
    /// behaviour. The token is hex, but the URL is still assembled via
    /// `URLComponents` so any existing query items are preserved and the
    /// result is always a valid URL. Exposed internally for unit testing.
    ///
    /// - Parameters:
    ///   - base: The dev server WebSocket URL (e.g. `ws://localhost:8174`).
    ///   - token: The hot reload token read from the loaded bundle.
    /// - Returns: `base` with a `token` query item appended, or `base` itself
    ///   when the token is empty or the URL cannot be decomposed.
    nonisolated static func hotReloadURL(base: URL, token: String) -> URL {
        guard !token.isEmpty else { return base }
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base
        }
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "token", value: token))
        components.queryItems = queryItems
        return components.url ?? base
    }

    // MARK: - Bundle loading

    private func loadBundle() {
        #if DEBUG
        if let wsURL = devServerURL {
            // Load the embedded bundle first so the vite-plugin-injected
            // __HOT_RELOAD_TOKEN__ global exists, then read it best-effort and
            // attach it to the hot reload WebSocket URL before connecting. The
            // HotReloadManager reconnects with the same URL, so the token
            // persists across reconnections.
            loadEmbeddedBundle { [weak self] in
                guard let self else { return }
                self.runtime.readHotReloadToken { token in
                    let url = VueNativeViewController.hotReloadURL(base: wsURL, token: token)
                    DispatchQueue.main.async {
                        HotReloadManager.shared.connect(to: url)
                    }
                }
            }
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

    /// Whether a failed embedded-bundle load should surface the DEBUG error
    /// overlay instead of failing silently. When a dev server is configured,
    /// `loadBundle()` only used the embedded bundle to seed the hot-reload
    /// token and still connects to the dev server afterward, so a missing
    /// embedded bundle there is not fatal. Exposed internally (rather than
    /// inlined) so this decision is unit-testable without touching the JS
    /// runtime.
    static func shouldShowMissingBundleOverlay(loadSucceeded: Bool, devServerURL: URL?) -> Bool {
        return !loadSucceeded && devServerURL == nil
    }

    private func loadEmbeddedBundle(onComplete: (() -> Void)? = nil) {
        let source: BundleSource = {
            if let fixtureBundleURL {
                return .file(url: fixtureBundleURL)
            }
            return .embedded(name: bundleName)
        }()
        runtime.loadBundle(source: source) { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }
                self.hasLoadedBundle = success
                if success {
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded()
                    self.emitDimensionsIfNeeded()
                } else {
                    #if DEBUG
                    if VueNativeViewController.shouldShowMissingBundleOverlay(loadSucceeded: success, devServerURL: self.devServerURL) {
                        ErrorOverlayView.show(
                            error: "Bundle '\(self.bundleName).js' not found — run `vue-native dev` (hot reload) or `vue-native run ios` to build it"
                        )
                    }
                    #endif
                }
                onComplete?()
            }
            if !success {
                NSLog("[VueNative] ERROR: Failed to load bundle '%@'", self?.bundleName ?? "unknown")
            }
        }
    }

    /// Wire the error overlay's Reload button to a full reload of the embedded
    /// bundle in a fresh JS context. A failed render can leave the old context
    /// in a mutated state, so the runtime is recreated and the bridge re-bound
    /// before re-loading — mirroring the OTA-fallback recovery path.
    private func installErrorReloadHandler() {
        ErrorOverlayView.reloadHandler = { [weak self] in
            guard let self else { return }
            self.runtime.recreate { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.bridge.reset()
                    self.bridge.initialize(rootViewController: self, hostID: self.hostID)
                    self.loadEmbeddedBundle()
                }
            }
        }
    }

    #if DEBUG
    /// Install the bottom-right hot-reload connection badge and wire it to
    /// `HotReloadManager`'s status callback. No-op when no dev server is
    /// configured -- production apps (and DEBUG builds without hot reload)
    /// never see it, matching `loadBundle()`'s dev-server gate.
    private func installHotReloadStatusIndicator() {
        guard devServerURL != nil else { return }

        let statusView = HotReloadStatusView()
        view.addSubview(statusView)
        NSLayoutConstraint.activate([
            statusView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            statusView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
        hotReloadStatusView = statusView

        HotReloadManager.shared.onStatusChange = { [weak statusView] status in
            DispatchQueue.main.async {
                statusView?.apply(status)
            }
        }
    }
    #endif

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
