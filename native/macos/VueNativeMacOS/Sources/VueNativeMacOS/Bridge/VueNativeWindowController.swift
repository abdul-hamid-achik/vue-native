import AppKit

/// Base window controller for Vue Native macOS apps.
/// Subclass and override `bundleName` and optionally `devServerURL`.
///
/// Usage:
/// ```swift
/// class MainWindowController: VueNativeWindowController {
///     override var bundleName: String { "vue-native-bundle" }
///     override var devServerURL: URL? {
///         #if DEBUG
///         URL(string: "ws://localhost:8174")
///         #else
///         nil
///         #endif
///     }
/// }
/// ```
open class VueNativeWindowController: NSWindowController {

    // MARK: - Overridable API

    /// Name of the JS bundle resource (without extension) bundled in your app target.
    open var bundleName: String { "vue-native-bundle" }

    /// Test hook: load this file instead of the embedded app resource.
    /// Production hosts leave this `nil`.
    open var fixtureBundleURL: URL? { nil }

    /// WebSocket URL of the Vite dev server for hot reload.
    /// Return `nil` (the default) to disable hot reload and load only from the bundle.
    open var devServerURL: URL? { nil }

    // MARK: - Custom component registration (escape hatch)

    /// Register a custom component factory under a component type name.
    ///
    /// Escape hatch for apps that need a native component not provided by
    /// Vue Native. Once registered, the component can be used from JS like any
    /// built-in (for example `h('MyComponent')`). Call this on the main thread
    /// before the bundle loads so the factory is available when views are created.
    ///
    /// - Parameters:
    ///   - name: The component type string (e.g. `"MyComponent"`).
    ///   - factory: The factory that creates and configures the native view.
    public static func registerComponent(_ name: String, factory: NativeComponentFactory) {
        ComponentRegistry.shared.register(name, factory: factory)
    }

    // MARK: - Private state

    private let runtime = JSRuntime.shared
    private let bridge  = NativeBridge.shared
    private let hostID = UUID()
    private var resizeObserver: NSObjectProtocol?
    private var lastDimensions: (width: CGFloat, height: CGFloat, scale: CGFloat)?
    private var hasLoadedBundle = false
    private var didStartHost = false
    #if DEBUG
    /// Bottom-right connection-status badge, installed only when a dev server
    /// is configured. `nil` otherwise (production apps never allocate it).
    private var hotReloadStatusView: HotReloadStatusView?
    #endif

    // MARK: - Convenience initializer

    public convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Vue Native"

        // Use a FlippedView as the content view so all coordinates are top-left origin.
        let initialBounds = window.contentView?.bounds
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let flippedContent = FlippedView(frame: initialBounds)
        flippedContent.autoresizingMask = [.width, .height]
        window.contentView = flippedContent

        self.init(window: window)
        // Assigning a window in init does not invoke windowDidLoad.
        startHostIfNeeded()
    }

    // MARK: - Lifecycle

    override open func windowDidLoad() {
        super.windowDidLoad()
        startHostIfNeeded()
    }

    /// Start the JS host exactly once. Programmatic `init(window:)` skips
    /// `windowDidLoad`, so the convenience initializer also calls this.
    private func startHostIfNeeded() {
        guard !didStartHost, let contentView = window?.contentView else { return }
        didStartHost = true

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor

        #if DEBUG
        installHotReloadStatusIndicator(in: contentView)
        #endif

        // Initialize JS engine first, then bridge.
        runtime.initializeForHost { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.bridge.initialize(contentView: contentView, hostID: self.hostID)
                self.loadBundle()
            }
        }

        if let window {
            resizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.emitDimensionsIfNeeded()
            }
        }
    }

    deinit {
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
        let hostID = hostID
        Task { @MainActor in
            let bridge = NativeBridge.shared
            if bridge.releaseHost(hostID: hostID) {
                JSRuntime.shared.invalidate()
            }
        }
    }

    private func emitDimensionsIfNeeded() {
        guard hasLoadedBundle else { return }
        guard let contentView = window?.contentView else { return }
        let size = contentView.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let scale = window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
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

    #if DEBUG
    /// Install the bottom-right hot-reload connection badge and wire it to
    /// `HotReloadManager`'s status callback. No-op when no dev server is
    /// configured -- production apps (and DEBUG builds without hot reload)
    /// never see it, matching `loadEmbeddedBundle()`'s dev-server gate.
    private func installHotReloadStatusIndicator(in contentView: NSView) {
        guard devServerURL != nil else { return }

        let statusView = HotReloadStatusView()
        contentView.addSubview(statusView)
        NSLayoutConstraint.activate([
            statusView.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            statusView.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
        hotReloadStatusView = statusView

        HotReloadManager.shared.onStatusChange = { [weak statusView] status in
            DispatchQueue.main.async {
                statusView?.apply(status)
            }
        }
    }
    #endif

    // MARK: - Hot Reload URL

    /// Build a hot-reload WebSocket URL, appending `?token=<token>` when the token is non-empty.
    /// Best-effort: returns `base` unmodified if the token is empty or URL construction fails.
    static func hotReloadURL(base: URL, token: String) -> URL {
        guard !token.isEmpty else { return base }
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base
        }
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "token", value: token)]
        return components.url ?? base
    }

    // MARK: - Bundle loading

    /// Whether a failed embedded-bundle load should surface the DEBUG error
    /// overlay instead of failing silently. Unlike iOS, the dev-server
    /// connection below only runs after a *successful* embedded load, so
    /// there is no working fallback when it fails — even with
    /// `devServerURL` configured. Exposed internally so this decision is
    /// unit-testable without touching the JS runtime.
    static func shouldShowMissingBundleOverlay(loadSucceeded: Bool) -> Bool {
        return !loadSucceeded
    }

    private func loadBundle() {
        loadEmbeddedBundle()
    }

    private func loadEmbeddedBundle() {
        let source: BundleSource = {
            if let fixtureBundleURL {
                return .file(url: fixtureBundleURL)
            }
            return .embedded(name: bundleName)
        }()
        runtime.loadBundle(source: source) { [weak self] success in
            // This closure runs on jsQueue — read the hot-reload token here (best-effort)
            // before hopping to the main thread.
            #if DEBUG
            let hotReloadToken: String = success
                ? (JSRuntime.shared.evaluateScriptSync("String(globalThis.__HOT_RELOAD_TOKEN__ || '')")?.toString() ?? "")
                : ""
            #endif
            DispatchQueue.main.async {
                guard let self else { return }
                self.hasLoadedBundle = success
                if success {
                    self.window?.contentView?.layoutSubtreeIfNeeded()
                    self.emitDimensionsIfNeeded()
                    #if DEBUG
                    if let wsURL = self.devServerURL {
                        HotReloadManager.shared.connect(to: Self.hotReloadURL(base: wsURL, token: hotReloadToken))
                    }
                    #endif
                } else {
                    #if DEBUG
                    if VueNativeWindowController.shouldShowMissingBundleOverlay(loadSucceeded: success) {
                        ErrorOverlayView.show(
                            message: "Bundle '\(self.bundleName).js' not found — run `vue-native dev` (hot reload) or `vue-native run macos` to build it",
                            stack: nil,
                            componentName: nil
                        )
                    }
                    #endif
                }
            }
            if !success {
                NSLog("[VueNative macOS] ERROR: Failed to load bundle '%@'", self?.bundleName ?? "unknown")
            }
        }
    }
}

// MARK: - VueNativeAppDelegate

/// Convenience NSApplicationDelegate for single-window Vue Native apps.
/// Subclass and override `createWindowController()` to provide your custom window controller.
///
/// Usage:
/// ```swift
/// @main
/// class AppDelegate: VueNativeAppDelegate {
///     override func createWindowController() -> VueNativeWindowController {
///         return MainWindowController()
///     }
/// }
/// ```
open class VueNativeAppDelegate: NSObject, NSApplicationDelegate {
    public var windowController: VueNativeWindowController?

    open func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = createWindowController()
        controller.showWindow(nil)
        windowController = controller
    }

    /// Override this to provide your custom VueNativeWindowController subclass.
    open func createWindowController() -> VueNativeWindowController {
        return VueNativeWindowController()
    }

    open func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
