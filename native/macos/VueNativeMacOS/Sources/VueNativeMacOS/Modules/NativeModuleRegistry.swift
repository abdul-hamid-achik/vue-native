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
        modules[module.moduleName] = module
    }

    /// Register all built-in macOS modules.
    func registerDefaults(dispatcher: NativeEventDispatcher, viewLookup: @escaping (Int) -> NSView?) {
        // Cross-platform ports
        register(HapticsModule())
        register(ClipboardModule())
        register(DeviceInfoModule())
        register(AnimationModule(viewLookup: viewLookup))
        register(AppStateModule(dispatcher: dispatcher))
        register(KeyboardModule())
        register(LinkingModule())
        register(ShareModule())

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
