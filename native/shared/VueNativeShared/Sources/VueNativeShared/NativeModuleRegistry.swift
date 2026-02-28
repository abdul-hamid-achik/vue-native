import Foundation

/// Registry for all native modules.
/// Modules are registered by name and looked up when JS invokes them.
/// Each platform registers its own set of modules — there is no `registerDefaults()` here.
public final class NativeModuleRegistry {

    public static let shared = NativeModuleRegistry()

    private var modules: [String: NativeModule] = [:]

    private init() {}

    // MARK: - Registration

    public func register(_ module: NativeModule) {
        modules[module.moduleName] = module
    }

    // MARK: - Invocation

    public func invoke(module moduleName: String, method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        guard let module = modules[moduleName] else {
            callback(nil, "Module '\(moduleName)' not found")
            return
        }
        module.invoke(method: method, args: args, callback: callback)
    }

    public func invokeSync(module moduleName: String, method: String, args: [Any]) -> Any? {
        guard let module = modules[moduleName] else {
            NSLog("[VueNative] NativeModuleRegistry: Module '\(moduleName)' not found")
            return nil
        }
        return module.invokeSync(method: method, args: args)
    }
}
