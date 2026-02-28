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
        let flippedContent = FlippedView(frame: window.contentView!.bounds)
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
        runtime.initialize { [weak self] in
            guard let self = self else { return }
            self.bridge.initialize(contentView: contentView)
            DispatchQueue.main.async {
                self.loadBundle()
            }
        }
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
        runtime.loadBundle(source: .embedded(name: bundleName)) { success in
            if !success {
                NSLog("[VueNative macOS] ERROR: Failed to load bundle '%@'", self.bundleName)
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
