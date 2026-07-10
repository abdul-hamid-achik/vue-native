import AppKit
import VueNativeShared

/// Singleton registry for all native modules.
/// Modules are registered by name and looked up when JS invokes them.
@MainActor
final class NativeModuleRegistry {

    static let shared = NativeModuleRegistry()

    private var modules: [String: NativeModule] = [:]

    private init() {}

    // MARK: - Registration

    func register(_ module: NativeModule) {
        let previous = modules.updateValue(module, forKey: module.moduleName)
        if let previous, previous !== module {
            previous.destroy()
        }
    }

    /// Destroy and unregister every module in the current snapshot.
    func removeAll() {
        let registeredModules = Array(modules.values)
        modules.removeAll(keepingCapacity: true)
        registeredModules.forEach { $0.destroy() }
    }

    /// Register all built-in macOS modules.
    func registerDefaults(dispatcher: NativeEventDispatcher, viewLookup: @escaping (Int) -> NSView?) {
        // Reinitialization must produce an exact registry snapshot. Clearing
        // first releases old host-bound modules and removes generated modules
        // that no longer exist in the current generated registry.
        removeAll()

        // Cross-platform ports
        register(HapticsModule())
        register(ClipboardModule())
        register(DeviceInfoModule())
        register(AnimationModule(viewLookup: viewLookup))
        register(AppStateModule(dispatcher: dispatcher))
        register(KeyboardModule())
        register(LinkingModule())
        register(ShareModule())
        register(AsyncStorageModule())
        register(FileSystemModule())
        register(SecureStorageModule())
        register(DatabaseModule())
        register(NetworkModule(eventDispatcher: dispatcher))
        register(GeolocationModule(eventDispatcher: dispatcher))
        register(PerformanceModule(eventDispatcher: dispatcher))
        register(AudioModule(eventDispatcher: dispatcher))
        register(WebSocketModule(eventDispatcher: dispatcher))

        // macOS-only modules
        register(WindowModule())
        register(MenuModule(dispatcher: dispatcher))
        register(FileDialogModule())
        register(DragDropModule(dispatcher: dispatcher))

        // Additional cross-platform modules
        register(CameraModule())
        register(NotificationsModule())
        register(BiometryModule())
        register(PermissionsModule())

        registerGeneratedModules()
    }

    // MARK: - Invocation

    func invoke(module moduleName: String, method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        guard let module = modules[moduleName] else {
            callback(nil, "Module '\(moduleName)' not found")
            return
        }
        module.invoke(method: method, args: args, callback: callback)
    }

    func invokeSync(module moduleName: String, method: String, args: [Any]) -> Any? {
        guard let module = modules[moduleName] else {
            NSLog("[VueNative] NativeModuleRegistry: Module '\(moduleName)' not found")
            return nil
        }
        return module.invokeSync(method: method, args: args)
    }
}
