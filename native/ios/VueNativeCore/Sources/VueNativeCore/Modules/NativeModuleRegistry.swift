#if canImport(UIKit)
import Foundation

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

    /// Register all built-in modules.
    func registerDefaults() {
        register(HapticsModule())
        register(AsyncStorageModule())
        register(ClipboardModule())
        register(DeviceInfoModule())
        register(KeyboardModule())
        register(AnimationModule())
        let bridge = NativeBridge.shared
        register(NetworkModule(bridge: bridge))
        register(AppStateModule(bridge: bridge))
        register(LinkingModule())
        register(ShareModule())
        // Phase 2 modules
        register(PermissionsModule())
        register(GeolocationModule(bridge: bridge))
        register(CameraModule())
        register(NotificationsModule(bridge: bridge))
        register(BiometryModule())
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
#endif
