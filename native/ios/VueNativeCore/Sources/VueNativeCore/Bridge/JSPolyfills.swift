#if canImport(UIKit)
import JavaScriptCore
import UIKit

/// Registers browser-like APIs in JSContext that the Vue runtime and application code expect.
/// All callbacks execute on the JS queue (not the main thread) unless noted otherwise.
enum JSPolyfills {

    // MARK: - Timer storage

    /// Active timers, keyed by string ID. Accessed only from JS queue.
    private static var timers: [String: Timer] = [:]
    /// Next timer ID counter. Accessed only from JS queue.
    private static var nextTimerId: Int = 1

    // MARK: - RAF storage

    /// Active display link for requestAnimationFrame. Accessed only from main thread.
    private static var displayLink: CADisplayLink?
    /// Pending requestAnimationFrame callbacks. Accessed only from JS queue.
    private static var rafCallbacks: [String: JSValue] = [:]
    /// Next RAF ID counter. Accessed only from JS queue.
    private static var nextRafId: Int = 1

    // MARK: - Reset

    /// Reset all polyfill state. Call before creating a fresh JSContext on hot reload.
    /// MUST be called on the JS queue.
    static func reset() {
        // Invalidate all active timers
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()

        // Clear RAF callbacks
        rafCallbacks.removeAll()

        // Reset counters
        nextTimerId = 1
        nextRafId = 1

        // Stop the display link
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Registration

    /// Register all polyfills into the given JSRuntime's context.
    /// MUST be called on the JS queue.
    static func register(in runtime: JSRuntime) {
        guard let context = runtime.context else { return }

        registerConsole(in: context)
        registerTimers(in: context, runtime: runtime)
        registerMicrotask(in: context)
        registerRAF(in: context, runtime: runtime)
        registerPerformance(in: context, runtime: runtime)
        registerGlobalThis(in: context)
        registerFetch(in: context, runtime: runtime)
    }

    // MARK: - console.log / warn / error

    private static func registerConsole(in context: JSContext) {
        // Create a console object
        context.evaluateScript("var console = {};")

        /// Helper: format all arguments passed from JS into a single space-separated string.
        func formatArgs() -> String {
            guard let args = JSContext.currentArguments() as? [JSValue], !args.isEmpty else {
                return ""
            }
            return args.map { value in
                value.isUndefined ? "undefined" : (value.toString() ?? "null")
            }.joined(separator: " ")
        }

        let consoleLog: @convention(block) () -> Void = {
            NSLog("[VueNative LOG] %@", formatArgs())
        }

        let consoleWarn: @convention(block) () -> Void = {
            NSLog("[VueNative WARN] %@", formatArgs())
        }

        let consoleError: @convention(block) () -> Void = {
            NSLog("[VueNative ERROR] %@", formatArgs())
        }

        let consoleDebug: @convention(block) () -> Void = {
            NSLog("[VueNative DEBUG] %@", formatArgs())
        }

        let consoleInfo: @convention(block) () -> Void = {
            NSLog("[VueNative INFO] %@", formatArgs())
        }

        let consoleObj = context.objectForKeyedSubscript("console")!
        consoleObj.setObject(consoleLog, forKeyedSubscript: "log" as NSString)
        consoleObj.setObject(consoleWarn, forKeyedSubscript: "warn" as NSString)
        consoleObj.setObject(consoleError, forKeyedSubscript: "error" as NSString)
        consoleObj.setObject(consoleDebug, forKeyedSubscript: "debug" as NSString)
        consoleObj.setObject(consoleInfo, forKeyedSubscript: "info" as NSString)
    }

    // MARK: - setTimeout / clearTimeout / setInterval / clearInterval

    private static func registerTimers(in context: JSContext, runtime: JSRuntime) {

        // setTimeout(callback, delay) -> timerId (String)
        let setTimeout: @convention(block) (JSValue, JSValue) -> JSValue = { [weak runtime] callback, delay in
            guard let runtime = runtime, let context = runtime.context else {
                return JSValue(nullIn: JSContext.current())
            }

            let delayMs = delay.isUndefined ? 0.0 : delay.toDouble()
            let timerId = String(nextTimerId)
            nextTimerId += 1

            // Protect callback from GC by storing in the context
            let callbackRef = JSManagedValue(value: callback)
            context.virtualMachine.addManagedReference(callbackRef, withOwner: context)

            // Schedule timer on a RunLoop that we pump from the JS queue
            // We use DispatchQueue.main for the timer, then dispatch callback to JS queue
            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: max(delayMs / 1000.0, 0.001), repeats: false) { [weak runtime] _ in
                    guard let runtime = runtime else { return }
                    runtime.jsQueue.async { [weak runtime] in
                        guard let runtime = runtime, let context = runtime.context else { return }
                        if let cb = callbackRef?.value, !cb.isUndefined {
                            cb.call(withArguments: [])
                            // Drain microtasks after timer callback
                            context.evaluateScript("void 0;")
                        }
                        context.virtualMachine.removeManagedReference(callbackRef, withOwner: context)
                        timers.removeValue(forKey: timerId)
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                runtime.jsQueue.async {
                    timers[timerId] = timer
                }
            }

            return JSValue(object: timerId, in: context)
        }

        // clearTimeout(timerId)
        let clearTimeout: @convention(block) (JSValue) -> Void = { timerId in
            guard let id = timerId.toString() else { return }
            if let timer = timers.removeValue(forKey: id) {
                // Timer invalidation must happen on the main thread where it was created
                DispatchQueue.main.async {
                    timer.invalidate()
                }
            }
        }

        // setInterval(callback, delay) -> timerId (String)
        let setInterval: @convention(block) (JSValue, JSValue) -> JSValue = { [weak runtime] callback, delay in
            guard let runtime = runtime, let context = runtime.context else {
                return JSValue(nullIn: JSContext.current())
            }

            let delayMs = delay.isUndefined ? 0.0 : delay.toDouble()
            let timerId = String(nextTimerId)
            nextTimerId += 1

            let callbackRef = JSManagedValue(value: callback)
            context.virtualMachine.addManagedReference(callbackRef, withOwner: context)

            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: max(delayMs / 1000.0, 0.001), repeats: true) { [weak runtime] _ in
                    guard let runtime = runtime else { return }
                    runtime.jsQueue.async { [weak runtime] in
                        guard let runtime = runtime, let context = runtime.context else { return }
                        if let cb = callbackRef?.value, !cb.isUndefined {
                            cb.call(withArguments: [])
                            context.evaluateScript("void 0;")
                        }
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                runtime.jsQueue.async {
                    timers[timerId] = timer
                }
            }

            return JSValue(object: timerId, in: context)
        }

        // clearInterval(timerId)
        let clearInterval: @convention(block) (JSValue) -> Void = { timerId in
            guard let id = timerId.toString() else { return }
            if let timer = timers[id] {
                DispatchQueue.main.async {
                    timer.invalidate()
                }
                timers.removeValue(forKey: id)
            }
        }

        context.setObject(setTimeout, forKeyedSubscript: "setTimeout" as NSString)
        context.setObject(clearTimeout, forKeyedSubscript: "clearTimeout" as NSString)
        context.setObject(setInterval, forKeyedSubscript: "setInterval" as NSString)
        context.setObject(clearInterval, forKeyedSubscript: "clearInterval" as NSString)
    }

    // MARK: - queueMicrotask

    private static func registerMicrotask(in context: JSContext) {
        // queueMicrotask uses Promise.resolve().then() since JSC has native Promise support.
        // This is exactly what Vue's scheduler uses internally.
        context.evaluateScript("""
            function queueMicrotask(callback) {
                Promise.resolve().then(callback);
            }
        """)
    }

    // MARK: - requestAnimationFrame / cancelAnimationFrame

    private static func registerRAF(in context: JSContext, runtime: JSRuntime) {

        // requestAnimationFrame(callback) -> rafId (String)
        let requestAnimationFrame: @convention(block) (JSValue) -> JSValue = { [weak runtime] callback in
            guard let runtime = runtime, let context = runtime.context else {
                return JSValue(nullIn: JSContext.current())
            }

            let rafId = String(nextRafId)
            nextRafId += 1

            // Store the callback in our dictionary. The strong reference from Swift
            // prevents JSC from garbage collecting it until we remove it.
            rafCallbacks[rafId] = callback

            // Ensure display link is running
            DispatchQueue.main.async {
                if displayLink == nil {
                    let target = DisplayLinkTarget(runtime: runtime)
                    let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.handleFrame(_:)))
                    link.add(to: .main, forMode: .common)
                    displayLink = link
                }
            }

            return JSValue(object: rafId, in: context)
        }

        // cancelAnimationFrame(rafId)
        let cancelAnimationFrame: @convention(block) (JSValue) -> Void = { [weak runtime] rafId in
            _ = runtime
            guard let id = rafId.toString() else { return }
            // Simply remove the callback; it won't fire on the next display link cycle
            rafCallbacks.removeValue(forKey: id)
        }

        context.setObject(requestAnimationFrame, forKeyedSubscript: "requestAnimationFrame" as NSString)
        context.setObject(cancelAnimationFrame, forKeyedSubscript: "cancelAnimationFrame" as NSString)
    }

    /// Called from the display link target on every frame.
    /// Dispatches all pending RAF callbacks to the JS queue.
    fileprivate static func fireRAFCallbacks(runtime: JSRuntime, timestamp: Double) {
        runtime.jsQueue.async { [weak runtime] in
            guard let runtime = runtime, let context = runtime.context else { return }

            // Snapshot and clear callbacks (RAF is one-shot)
            let callbacks = rafCallbacks
            rafCallbacks.removeAll()

            for (_, callback) in callbacks {
                if !callback.isUndefined {
                    callback.call(withArguments: [timestamp])
                }
            }

            // Drain microtasks after all RAF callbacks
            if !callbacks.isEmpty {
                context.evaluateScript("void 0;")
            }

            // If no more callbacks pending, stop the display link
            if rafCallbacks.isEmpty {
                DispatchQueue.main.async {
                    displayLink?.invalidate()
                    displayLink = nil
                }
            }
        }
    }

    // MARK: - performance.now()

    private static func registerPerformance(in context: JSContext, runtime: JSRuntime) {
        context.evaluateScript("var performance = {};")

        let performanceNow: @convention(block) () -> Double = { [weak runtime] in
            guard let runtime = runtime else { return 0 }
            // Return milliseconds since runtime start
            return (CFAbsoluteTimeGetCurrent() - runtime.startTime) * 1000.0
        }

        let perfObj = context.objectForKeyedSubscript("performance")!
        perfObj.setObject(performanceNow, forKeyedSubscript: "now" as NSString)
    }

    // MARK: - globalThis

    private static func registerGlobalThis(in context: JSContext) {
        // Ensure globalThis points to the global object (may already be set)
        context.evaluateScript("""
            if (typeof globalThis === 'undefined') {
                var globalThis = this;
            }
        """)
    }

    // MARK: - fetch

    private static func registerFetch(in context: JSContext, runtime: JSRuntime) {
        // Register __VN_configurePins(pinsJSON) for certificate pinning from JS.
        // pinsJSON is a JSON string: { "domain": ["sha256/hash1", "sha256/hash2"] }
        let configurePins: @convention(block) (JSValue) -> Void = { pinsValue in
            guard let jsonString = pinsValue.toString(),
                  let data = jsonString.data(using: .utf8),
                  let pinsDict = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] else {
                NSLog("[VueNative CertPin] Invalid pins configuration")
                return
            }
            CertificatePinning.shared.configurePins(pinsDict)
            NSLog("[VueNative CertPin] Configured pins for %d domains", pinsDict.count)
        }
        context.setObject(configurePins, forKeyedSubscript: "__VN_configurePins" as NSString)

        // fetch(url, options?) -> Promise<Response>
        let fetch: @convention(block) (JSValue, JSValue) -> JSValue = { [weak runtime] urlValue, optionsValue in
            guard let runtime = runtime, let context = runtime.context else {
                return JSValue(undefinedIn: JSContext.current())
            }

            let urlString = urlValue.toString() ?? ""
            guard let url = URL(string: urlString) else {
                return context.evaluateScript("Promise.reject(new TypeError('Invalid URL'))")!
            }

            // Build URLRequest
            var request = URLRequest(url: url)

            if !optionsValue.isUndefined && !optionsValue.isNull {
                if let method = optionsValue.objectForKeyedSubscript("method")?.toString() {
                    request.httpMethod = method.uppercased()
                } else {
                    request.httpMethod = "GET"
                }
                if let headersObj = optionsValue.objectForKeyedSubscript("headers"),
                   !headersObj.isUndefined, !headersObj.isNull,
                   let headers = headersObj.toDictionary() as? [String: String] {
                    for (key, val) in headers {
                        request.setValue(val, forHTTPHeaderField: key)
                    }
                }
                if let body = optionsValue.objectForKeyedSubscript("body"),
                   !body.isUndefined, !body.isNull,
                   let bodyStr = body.toString() {
                    request.httpBody = bodyStr.data(using: .utf8)
                }
            } else {
                request.httpMethod = "GET"
            }

            // Create a Promise via JS with captured resolve/reject
            var resolveRef: JSValue?
            var rejectRef: JSValue?

            let captureExecutor: @convention(block) (JSValue, JSValue) -> Void = { resolve, reject in
                resolveRef = resolve
                rejectRef = reject
            }

            let promiseCtor = context.evaluateScript("""
                (function(executor) {
                    return new Promise(executor);
                })
            """)
            let captureBlock = JSValue(object: captureExecutor as AnyObject, in: context)
            let promise = promiseCtor?.call(withArguments: [captureBlock as Any])

            // Use the pinning session when pins are configured for this host,
            // otherwise fall back to URLSession.shared for zero overhead.
            let host = url.host ?? ""
            let urlSession = CertificatePinning.shared.hasPins(for: host)
                ? CertificatePinning.shared.session
                : URLSession.shared

            let task = urlSession.dataTask(with: request) { [weak runtime] data, response, error in
                guard let runtime = runtime else { return }
                runtime.jsQueue.async { [weak runtime] in
                    guard runtime != nil, let context = runtime?.context else { return }

                    if let error = error {
                        let errMsg = error.localizedDescription
                        if let reject = rejectRef, !reject.isUndefined {
                            let errObj = context.evaluateScript("new Error(\(JSPolyfillsJSON.encode(errMsg)))")
                            reject.call(withArguments: [errObj as Any])
                        }
                        return
                    }

                    let httpResponse = response as? HTTPURLResponse
                    let status = httpResponse?.statusCode ?? 200
                    let ok = (200...299).contains(status)
                    let bodyData = data ?? Data()
                    let bodyString = String(data: bodyData, encoding: .utf8) ?? ""

                    // Build headers dictionary
                    var headersDict: [String: String] = [:]
                    if let httpResp = httpResponse {
                        for (k, v) in httpResp.allHeaderFields {
                            headersDict["\(k)"] = "\(v)"
                        }
                    }

                    // Create response object in JS
                    if let resolve = resolveRef, !resolve.isUndefined {
                        let responseObj = JSValue(newObjectIn: context)!
                        responseObj.setObject(status, forKeyedSubscript: "status" as NSString)
                        responseObj.setObject(ok, forKeyedSubscript: "ok" as NSString)
                        responseObj.setObject(bodyString, forKeyedSubscript: "_body" as NSString)

                        // headers object
                        let headersObj = JSValue(newObjectIn: context)!
                        for (k, v) in headersDict {
                            headersObj.setObject(v, forKeyedSubscript: k as NSString)
                        }
                        responseObj.setObject(headersObj, forKeyedSubscript: "headers" as NSString)

                        // .text() method
                        let bodyStringCopy = bodyString
                        let textMethod: @convention(block) () -> JSValue = {
                            return context.evaluateScript("Promise.resolve(\(JSPolyfillsJSON.encode(bodyStringCopy)))")!
                        }
                        responseObj.setObject(textMethod, forKeyedSubscript: "text" as NSString)

                        // .json() method
                        let jsonMethod: @convention(block) () -> JSValue = {
                            return context.evaluateScript("(function(s){ try { return Promise.resolve(JSON.parse(s)); } catch(e) { return Promise.reject(e); } })(\(JSPolyfillsJSON.encode(bodyStringCopy)))")!
                        }
                        responseObj.setObject(jsonMethod, forKeyedSubscript: "json" as NSString)

                        resolve.call(withArguments: [responseObj])
                    }
                }
            }
            task.resume()

            return promise ?? JSValue(undefinedIn: context)
        }

        context.setObject(fetch, forKeyedSubscript: "fetch" as NSString)
    }
}

// MARK: - JSON encode helper

/// Produce a JSON-safe string literal (with quotes) for embedding in JS eval strings.
private enum JSPolyfillsJSON {
    static func encode(_ str: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: str)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "\"\""
    }
}

// MARK: - DisplayLinkTarget

/// Separate NSObject target for CADisplayLink to avoid retain cycles with JSRuntime.
private final class DisplayLinkTarget: NSObject {
    private weak var runtime: JSRuntime?

    init(runtime: JSRuntime) {
        self.runtime = runtime
        super.init()
    }

    @objc func handleFrame(_ link: CADisplayLink) {
        guard let runtime = runtime else {
            link.invalidate()
            return
        }
        let timestamp = link.timestamp * 1000.0 // Convert to milliseconds
        JSPolyfills.fireRAFCallbacks(runtime: runtime, timestamp: timestamp)
    }
}
#endif
