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

    /// WebSocket URL of the Vite dev server for hot reload.
    /// Return `nil` (the default) to disable hot reload and load only from the bundle.
    open var devServerURL: URL? { nil }

    // MARK: - Private state

    private let runtime = JSRuntime.shared
    private let bridge  = NativeBridge.shared
    private let hostID = UUID()
    private var resizeObserver: NSObjectProtocol?
    private var lastDimensions: (width: CGFloat, height: CGFloat, scale: CGFloat)?
    private var hasLoadedBundle = false

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
    }

    // MARK: - Lifecycle

    override open func windowDidLoad() {
        super.windowDidLoad()

        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor

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

    // MARK: - Bundle loading

    private func loadBundle() {
        #if DEBUG
        if let wsURL = devServerURL {
            HotReloadManager.shared.connect(to: wsURL)
        }
        #endif
        loadEmbeddedBundle()
    }

    private func loadEmbeddedBundle() {
        runtime.loadBundle(source: .embedded(name: bundleName)) { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }
                self.hasLoadedBundle = success
                if success {
                    self.window?.contentView?.layoutSubtreeIfNeeded()
                    self.emitDimensionsIfNeeded()
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
