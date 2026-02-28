import JavaScriptCore
import Foundation

// MARK: - Bundle Source

/// Describes where to load the JS application bundle from.
public enum BundleSource {
    /// Load from an embedded resource in the app bundle.
    case embedded(name: String)
    /// Load from a development server URL (for live reload).
    case devServer(url: URL)
}

// MARK: - JSRuntime

/// Core JavaScript runtime manager for macOS. Wraps JSContext on a dedicated serial DispatchQueue.
/// All JS operations are guaranteed to execute on the JS queue. AppKit operations
/// are never performed on this queue.
///
/// Thread safety contract:
/// - All JSContext access happens exclusively on `jsQueue`
/// - Never pass JSValue across threads -- extract primitives first
/// - All closures registered with JSContext use [weak self]
public final class JSRuntime: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = JSRuntime()

    // MARK: - Properties

    /// Dedicated serial queue for all JavaScript execution.
    /// QoS is userInteractive because JS drives the UI pipeline.
    public let jsQueue = DispatchQueue(label: "com.vuenative.macos.js", qos: .userInteractive)

    /// The underlying JavaScriptCore context. Only access on jsQueue.
    public private(set) var context: JSContext!

    /// Whether the runtime has been initialized.
    public private(set) var isInitialized = false

    /// Startup time reference for performance.now()
    public let startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    // MARK: - Initialization

    private init() {}

    /// Initialize the JS runtime. Creates the JSContext on the JS queue,
    /// configures exception handling, and registers polyfills.
    /// Must be called before any other method.
    public func initialize(completion: (() -> Void)? = nil) {
        jsQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isInitialized else {
                completion?()
                return
            }

            self.context = JSContext()

            self.context.exceptionHandler = { [weak self] context, exception in
                guard let exception = exception else { return }
                let message = exception.toString() ?? "Unknown JS error"
                let line = exception.objectForKeyedSubscript("line")?.toInt32() ?? 0
                let column = exception.objectForKeyedSubscript("column")?.toInt32() ?? 0
                let stack = exception.objectForKeyedSubscript("stack")?.toString() ?? ""
                NSLog("[VueNative macOS JS Error] \(message) at line \(line):\(column)")
                if !stack.isEmpty {
                    NSLog("[VueNative macOS JS Stack] \(stack)")
                }
                #if DEBUG
                let fullMessage = stack.isEmpty ? message : "\(message)\n\n\(stack)"
                ErrorOverlayView.show(error: fullMessage)
                #endif
                _ = self
            }

            self.context.evaluateScript("var globalThis = this;")

            // Register polyfills
            JSPolyfills.register(in: self)

            self.isInitialized = true
            completion?()
        }
    }

    // MARK: - Script Evaluation

    /// Evaluate a JavaScript string on the JS queue.
    public func evaluateScript(_ script: String, sourceURL: String? = nil, completion: ((JSValue?) -> Void)? = nil) {
        jsQueue.async { [weak self] in
            guard let self = self, let context = self.context else {
                completion?(nil)
                return
            }

            let result: JSValue?
            if let sourceURL = sourceURL, let url = URL(string: sourceURL) {
                result = context.evaluateScript(script, withSourceURL: url)
            } else {
                result = context.evaluateScript(script)
            }

            // Force microtask drain after evaluation.
            context.evaluateScript("void 0;")

            completion?(result)
        }
    }

    /// Evaluate a script synchronously. MUST only be called from the JS queue.
    @discardableResult
    public func evaluateScriptSync(_ script: String, sourceURL: String? = nil) -> JSValue? {
        dispatchPrecondition(condition: .onQueue(jsQueue))
        guard let context = context else { return nil }

        let result: JSValue?
        if let sourceURL = sourceURL, let url = URL(string: sourceURL) {
            result = context.evaluateScript(script, withSourceURL: url)
        } else {
            result = context.evaluateScript(script)
        }

        context.evaluateScript("void 0;")
        return result
    }

    // MARK: - Function Calls

    /// Call a global JS function by name with arguments. Runs on the JS queue.
    public func callFunction(_ name: String, withArguments args: [Any], completion: ((JSValue?) -> Void)? = nil) {
        jsQueue.async { [weak self] in
            guard let self = self, let context = self.context else {
                completion?(nil)
                return
            }

            let function = context.objectForKeyedSubscript(name)
            guard let fn = function, !fn.isUndefined else {
                NSLog("[VueNative macOS] Warning: JS function '\(name)' not found")
                completion?(nil)
                return
            }

            let result = fn.call(withArguments: args)
            context.evaluateScript("void 0;")

            completion?(result)
        }
    }

    /// Call a global JS function synchronously. MUST only be called from the JS queue.
    @discardableResult
    public func callFunctionSync(_ name: String, withArguments args: [Any]) -> JSValue? {
        dispatchPrecondition(condition: .onQueue(jsQueue))
        guard let context = context else { return nil }

        let function = context.objectForKeyedSubscript(name)
        guard let fn = function, !fn.isUndefined else {
            NSLog("[VueNative macOS] Warning: JS function '\(name)' not found")
            return nil
        }

        let result = fn.call(withArguments: args)
        context.evaluateScript("void 0;")
        return result
    }

    // MARK: - Function Registration

    /// Register a Swift function as a global JS function.
    public func registerFunction(_ name: String, block: @escaping @convention(block) (JSValue) -> Void) {
        jsQueue.async { [weak self] in
            guard let self = self, let context = self.context else { return }
            let wrappedBlock: @convention(block) (JSValue) -> Void = { [weak self] value in
                _ = self
                block(value)
            }
            context.setObject(wrappedBlock, forKeyedSubscript: name as NSString)
        }
    }

    // MARK: - Bundle Loading

    /// Load a JS application bundle from the given source.
    public func loadBundle(source: BundleSource, completion: ((Bool) -> Void)? = nil) {
        jsQueue.async { [weak self] in
            guard let self = self, self.context != nil else {
                completion?(false)
                return
            }

            switch source {
            case .embedded(let name):
                self.loadEmbeddedBundle(name: name, completion: completion)
            case .devServer(let url):
                self.loadDevServerBundle(url: url, completion: completion)
            }
        }
    }

    // MARK: - Private: Bundle Loading

    private func loadEmbeddedBundle(name: String, completion: ((Bool) -> Void)?) {
        let bundleName: String
        let bundleExtension: String

        if name.contains(".") {
            let parts = name.split(separator: ".", maxSplits: 1)
            bundleName = String(parts[0])
            bundleExtension = String(parts[1])
        } else {
            bundleName = name
            bundleExtension = "js"
        }

        var scriptURL: URL?

        if let url = Bundle.main.url(forResource: bundleName, withExtension: bundleExtension) {
            scriptURL = url
        } else {
            #if SWIFT_PACKAGE
            if let url = Bundle.module.url(forResource: bundleName, withExtension: bundleExtension) {
                scriptURL = url
            }
            #endif
        }

        guard let url = scriptURL else {
            NSLog("[VueNative macOS] Error: Bundle '\(name)' not found in app resources")
            completion?(false)
            return
        }

        do {
            let script = try String(contentsOf: url, encoding: .utf8)
            NSLog("[VueNative macOS] Loading bundle: \(name) (\(script.count) bytes)")
            self.context.evaluateScript(script, withSourceURL: url)
            self.context.evaluateScript("void 0;")
            NSLog("[VueNative macOS] Bundle loaded successfully")
            completion?(true)
        } catch {
            NSLog("[VueNative macOS] Error loading bundle '\(name)': \(error.localizedDescription)")
            completion?(false)
        }
    }

    private func loadDevServerBundle(url: URL, completion: ((Bool) -> Void)?) {
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else {
                completion?(false)
                return
            }

            self.jsQueue.async { [weak self] in
                guard let self = self, self.context != nil else {
                    completion?(false)
                    return
                }

                if let error = error {
                    NSLog("[VueNative macOS] Dev server error: \(error.localizedDescription)")
                    completion?(false)
                    return
                }

                guard let data = data, let script = String(data: data, encoding: .utf8) else {
                    NSLog("[VueNative macOS] Dev server returned invalid data")
                    completion?(false)
                    return
                }

                NSLog("[VueNative macOS] Loading dev bundle from \(url) (\(script.count) bytes)")
                self.context.evaluateScript(script, withSourceURL: url)
                self.context.evaluateScript("void 0;")
                NSLog("[VueNative macOS] Dev bundle loaded successfully")
                completion?(true)
            }
        }
        task.resume()
    }

    // MARK: - Hot Reload

    /// Reload the runtime with a new JavaScript bundle string.
    public func reload(bundle: String, completion: ((Bool) -> Void)? = nil) {
        jsQueue.async { [weak self] in
            guard let self = self else {
                completion?(false)
                return
            }

            NSLog("[VueNative macOS] Hot reload: tearing down old context...")

            if let teardown = self.context?.objectForKeyedSubscript("__VN_teardown"),
               !teardown.isUndefined {
                teardown.call(withArguments: [])
                self.context?.evaluateScript("void 0;")
            }

            JSPolyfills.reset()

            self.context = JSContext()
            self.context.exceptionHandler = { [weak self] _, exception in
                guard let exception = exception else { return }
                let message = exception.toString() ?? "Unknown JS error"
                let line = exception.objectForKeyedSubscript("line")?.toInt32() ?? 0
                let stack = exception.objectForKeyedSubscript("stack")?.toString() ?? ""
                NSLog("[VueNative macOS JS Error] \(message) at line \(line)")
                #if DEBUG
                let fullMessage = stack.isEmpty ? message : "\(message)\n\n\(stack)"
                ErrorOverlayView.show(error: fullMessage)
                #endif
                _ = self
            }

            self.context.evaluateScript("var globalThis = this;")
            JSPolyfills.register(in: self)

            NSLog("[VueNative macOS] Hot reload: evaluating new bundle (\(bundle.count) bytes)...")
            self.context.evaluateScript(bundle)
            if let exception = self.context.exception {
                NSLog("[VueNative macOS] Hot reload bundle error: %@", exception.toString() ?? "unknown")
                self.context.exception = nil
                completion?(false)
                return
            }
            self.context.evaluateScript("void 0;")
            NSLog("[VueNative macOS] Hot reload: complete")

            completion?(true)
        }
    }

    // MARK: - Teardown

    public func invalidate() {
        jsQueue.async { [weak self] in
            guard let self = self else { return }
            self.context = nil
            self.isInitialized = false
            NSLog("[VueNative macOS] JS runtime invalidated")
        }
    }
}
