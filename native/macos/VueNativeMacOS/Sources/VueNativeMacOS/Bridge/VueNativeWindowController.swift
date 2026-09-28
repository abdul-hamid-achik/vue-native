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

    /// Provide the factory for an *optional* component — one whose
    /// implementation lives in an add-on product that `VueNativeMacOS`
    /// deliberately does not link against (`VueNativeMacOSSVG` owns `<VSVG>`, the
    /// framework's only SVGKit consumer).
    ///
    /// Add-on products call this from their own bootstrap; host apps should not
    /// need it directly — use ``registerComponent(_:factory:)`` for your own
    /// components. Unlike that method, this one also survives being called
    /// before the component registry exists, because the factory is recorded for
    /// the registry's default-registration pass as well as registered
    /// immediately when the registry is already live.
    ///
    /// ```swift
    /// // What `VueNativeMacOSSVG.register()` does:
    /// VueNativeWindowController.provideOptionalComponent("VSVG", factory: VSVGFactory())
    /// ```
    public static func provideOptionalComponent(_ name: String, factory: NativeComponentFactory) {
        ComponentRegistry.provideOptionalComponent(name, factory: factory)
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
        // The platform window surface (`NSColor.windowBackgroundColor`) rather
        // than a hardcoded black, so the app does not boot to a black window in
        // Light Mode. Routed through StyleEngine's dynamic-color path so AppKit
        // re-resolves it on every appearance change instead of snapshotting the
        // mode the host happened to launch in.
        StyleEngine.apply(key: "backgroundColor", value: "background", to: contentView)

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

/// Convenience NSApplicationDelegate for **single-window** Vue Native apps.
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
///
/// ## Single-window limitation (important)
///
/// `NativeBridge.shared` and `JSRuntime.shared` are **process-wide singletons**:
/// there is exactly one JS context, one view registry and one module registry
/// for the whole app. Creating a second `VueNativeWindowController` therefore
/// does *not* give you a second Vue app — `NativeBridge.initialize` detects the
/// differing content view, logs a diagnostic, and tears the first window's
/// registry down before adopting the new one. The first window keeps its views
/// on screen but stops receiving updates.
///
/// Multi-window support needs a per-window bridge/runtime and is not
/// implemented. For a second window today, use `Modules/WindowModule.swift`
/// helpers on the single hosted window, or render the extra UI as a `VModal`.
open class VueNativeAppDelegate: NSObject, NSApplicationDelegate {
    public var windowController: VueNativeWindowController?

    open func applicationDidFinishLaunching(_ notification: Notification) {
        // A programmatically launched `NSApplication` has no nib/xib, so AppKit
        // gives it an *empty* menu bar unless one is installed. That is not
        // merely cosmetic: AppKit routes key equivalents through the main menu,
        // so without it Cmd+Q does not quit and Cmd+C/V/X/A never reach a
        // focused `VInput`. Install before the window shows.
        VueNativeAppDelegate.installMainMenuIfNeeded(makeMainMenu())

        let controller = createWindowController()
        controller.showWindow(nil)
        windowController = controller
    }

    /// Install `menu` as the application's main menu unless the host already has
    /// one (an app that builds its own menu earlier, or a nib/xib-based host,
    /// must win). Returns whether it installed.
    ///
    /// Exposed as a static so the "empty menu bar" fix is unit-testable without
    /// launching a window and disturbing the single-process `NativeBridge`.
    @discardableResult
    public static func installMainMenuIfNeeded(
        _ menu: NSMenu = VueNativeAppDelegate.standardMainMenu(),
        on app: NSApplication = NSApp
    ) -> Bool {
        guard app.mainMenu == nil else { return false }
        app.mainMenu = menu
        return true
    }

    /// Override this to provide your custom VueNativeWindowController subclass.
    open func createWindowController() -> VueNativeWindowController {
        return VueNativeWindowController()
    }

    /// The menu installed as `NSApp.mainMenu` at launch.
    ///
    /// Override to replace the whole menu, or call `super` and mutate the
    /// result to extend it. `MenuModule.setAppMenu` merges into whatever is
    /// installed here rather than replacing it.
    open func makeMainMenu() -> NSMenu {
        return VueNativeAppDelegate.standardMainMenu()
    }

    open func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Standard main menu

    /// Display name used for the application menu's About item.
    static func appName() -> String {
        if let bundleName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)?
            .trimmingCharacters(in: .whitespaces), !bundleName.isEmpty {
            return bundleName
        }
        let process = ProcessInfo.processInfo.processName
        return process.isEmpty ? "Vue Native" : process
    }

    /// Build the canonical App / Edit / View / Window / Help menu bar with the
    /// standard AppKit selectors and key equivalents.
    ///
    /// Every item's `target` is `nil`, so the action travels the responder
    /// chain — that is what makes Cmd+C/V/X/A work inside a focused `VInput`
    /// (its field editor) and Cmd+W close the front window. The returned menu is
    /// also wired into `NSApp.servicesMenu`, `NSApp.windowsMenu` and
    /// `NSApp.helpMenu` so AppKit populates the Services/Windows/Help items and
    /// keeps the Window menu in sync with the open windows.
    public static func standardMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.autoenablesItems = true

        // MARK: Application menu
        // The first top-level item is always the application menu on macOS;
        // its title is ignored by AppKit.
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "About \(VueNativeAppDelegate.appName())",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(servicesItem)

        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others",
                                         action: #selector(NSApplication.hideOtherApplications(_:)),
                                         keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = NSEvent.ModifierFlags([.command, .option])
        appMenu.addItem(withTitle: "Show All",
                        action: #selector(NSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        // MARK: Edit
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "Undo", action: NSSelectorFromString("undo:"), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: NSSelectorFromString("redo:"), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = NSEvent.ModifierFlags([.command, .shift])
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        let pasteAndMatch = editMenu.addItem(withTitle: "Paste and Match Style",
                                             action: NSSelectorFromString("pasteAsRichText:"),
                                             keyEquivalent: "v")
        pasteAndMatch.keyEquivalentModifierMask = NSEvent.ModifierFlags([.command, .shift, .option])
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // MARK: View
        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        let fullScreen = viewMenu.addItem(withTitle: "Enter Full Screen",
                                          action: #selector(NSWindow.toggleFullScreen(_:)),
                                          keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = NSEvent.ModifierFlags([.command, .control])

        // MARK: Window
        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(withTitle: "Minimize",
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom",
                           action: #selector(NSWindow.performZoom(_:)),
                           keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Close",
                           action: #selector(NSWindow.performClose(_:)),
                           keyEquivalent: "w")
        NSApp.windowsMenu = windowMenu

        // MARK: Help
        let helpMenuItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        NSApp.helpMenu = helpMenu

        return mainMenu
    }
}
