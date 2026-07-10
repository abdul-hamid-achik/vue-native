import Foundation

/// Protocol that all native modules must conform to.
/// Modules are registered with NativeModuleRegistry and invoked from JS
/// via the platform-specific bridge's invokeNativeModule / invokeNativeModuleSync operations.
public protocol NativeModule: AnyObject {
    /// The name used to identify this module from JS (e.g. "Haptics", "AsyncStorage").
    var moduleName: String { get }

    /// Invoke a method asynchronously.
    /// - Parameters:
    ///   - method: The method name to invoke.
    ///   - args: Arguments passed from JS.
    ///   - callback: Called when the method completes. Pass (result, nil) on success,
    ///               (nil, errorMessage) on failure.
    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void)

    /// Invoke a method synchronously and return the result.
    /// Use sparingly — prefer the async variant.
    func invokeSync(method: String, args: [Any]) -> Any?

    /// Release resources owned by this module before it is unregistered.
    ///
    /// Platform registries call this synchronously when replacing a module or
    /// resetting the registry. Implementations must be idempotent and should
    /// stop timers, observers, sessions, and other long-lived work without
    /// dispatching new events back to JavaScript.
    func destroy()
}

public extension NativeModule {
    /// Default sync implementation: just returns nil.
    func invokeSync(method: String, args: [Any]) -> Any? { return nil }

    /// Stateless modules require no explicit cleanup.
    func destroy() {}
}
