#if canImport(UIKit)
import JavaScriptCore
import Security
import UIKit

/// Registers browser-like APIs in JSContext that the Vue runtime and application code expect.
/// All callbacks execute on the JS queue (not the main thread) unless noted otherwise.
enum JSPolyfills {

    // MARK: - Timer storage

    /// Holds a scheduled Timer alongside its JSManagedValue so both can be cleaned up
    /// together.
    ///
    /// `timer` is optional because the entry is created **synchronously on the JS
    /// queue** as a tombstone, before the `DispatchQueue.main.async` block that
    /// actually builds the `Timer` gets to run. That tombstone is what makes a
    /// same-tick `clearTimeout` work: without it the map held nothing at clear time,
    /// so the clear removed nothing and the later store guard (`if timers[id] == nil`)
    /// could not distinguish "never stored yet" from "already cleared" — it stored the
    /// Timer and the callback fired anyway.
    private struct TimerEntry {
        var timer: Timer?
        let callbackRef: JSManagedValue?
    }

    /// Serial queue that guards all mutable timer/RAF state.
    /// Timer callbacks fire on the main thread and clear/read `timers`;
    /// JS queue closures also mutate `timers` (via setTimeout/clearTimeout).
    /// This queue serializes all access to prevent data races.
    private static let stateQueue = DispatchQueue(label: "com.vuenative.polyfills.state")

    /// Active timers, keyed by string ID. Access ONLY via `stateQueue`.
    private static var timers: [String: TimerEntry] = [:]
    /// Next timer ID counter. Access ONLY via `stateQueue`.
    private static var nextTimerId: Int = 1

    // MARK: - RAF storage

    /// Active display link for requestAnimationFrame. Accessed only from main thread.
    private static var displayLink: CADisplayLink?
    /// Pending requestAnimationFrame callbacks. Access ONLY via `stateQueue`.
    private static var rafCallbacks: [String: JSValue] = [:]
    /// Next RAF ID counter. Access ONLY via `stateQueue`.
    private static var nextRafId: Int = 1

    // MARK: - Reset

    /// Reset all polyfill state. Call before creating a fresh JSContext on hot reload.
    /// Safe to call from any thread — synchronizes internally via `stateQueue`.
    static func reset() {
        // Snapshot and clear timer/RAF state under the lock
        let oldTimers: [String: TimerEntry] = stateQueue.sync {
            let snapshot = timers
            timers.removeAll()
            rafCallbacks.removeAll()
            nextTimerId = 1
            nextRafId = 1
            return snapshot
        }

        // Invalidate timers on the main thread (where they were scheduled).
        // Tombstones have no Timer yet; their pending main-queue block finds the map
        // empty and arms nothing.
        DispatchQueue.main.async {
            for (_, entry) in oldTimers {
                entry.timer?.invalidate()
            }
            // Stop the display link
            displayLink?.invalidate()
            displayLink = nil
        }
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
        registerBase64(in: context)
        registerTextEncoding(in: context)
        registerURL(in: context)
        registerCrypto(in: context)
        registerBridgeStubs(in: context)
    }

    // MARK: - Bridge callback stubs

    /// Register no-op stubs for global functions that the bundle will overwrite.
    /// Native modules may call dispatchGlobalEvent() before the JS bundle has
    /// loaded and registered the real handlers — these stubs prevent the
    /// "JS function 'X' not found" warnings during that window.
    private static func registerBridgeStubs(in context: JSContext) {
        context.evaluateScript("""
            if (typeof __VN_handleGlobalEvent === 'undefined') {
                globalThis.__VN_handleGlobalEvent = function() {};
            }
            if (typeof __VN_handleEvent === 'undefined') {
                globalThis.__VN_handleEvent = function() {};
            }
            if (typeof __VN_resolveCallback === 'undefined') {
                globalThis.__VN_resolveCallback = function() {};
            }
        """)
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

        guard let consoleObj = context.objectForKeyedSubscript("console") else {
            NSLog("[VueNative] Warning: failed to get console object")
            return
        }
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
            let timerId: String = stateQueue.sync {
                let id = String(nextTimerId)
                nextTimerId += 1
                return id
            }

            // Protect callback from GC by storing in the context
            let callbackRef = JSManagedValue(value: callback)
            context.virtualMachine.addManagedReference(callbackRef, withOwner: context)

            // Reserve the ID synchronously on this (JS) queue. A `clearTimeout` later
            // in the same tick then finds an entry to remove; see `TimerEntry`.
            stateQueue.sync {
                timers[timerId] = TimerEntry(timer: nil, callbackRef: callbackRef)
            }

            // Schedule timer on the main thread RunLoop, then dispatch callback to JS queue
            DispatchQueue.main.async {
                // `clearTimeout` may have removed the tombstone before this block ran.
                // Arm nothing in that case — otherwise the callback fires even though
                // JS already cancelled it.
                let stillPending: Bool = stateQueue.sync { timers[timerId] != nil }
                guard stillPending else { return }

                let timer = Timer.scheduledTimer(withTimeInterval: max(delayMs / 1000.0, 0.001), repeats: false) { [weak runtime] _ in
                    guard let runtime = runtime else { return }
                    runtime.jsQueue.async { [weak runtime] in
                        guard let runtime = runtime, let context = runtime.context else { return }
                        // Timer already fired — only invoke if not cleared. Reading the
                        // ref out of the map (rather than the captured one) means a clear
                        // that landed after the Timer fired still suppresses the call.
                        let firedRef: JSManagedValue? = stateQueue.sync {
                            timers.removeValue(forKey: timerId)?.callbackRef
                        }
                        guard let firedRef else { return }
                        if let cb = firedRef.value, !cb.isUndefined {
                            cb.call(withArguments: [])
                            // Drain microtasks after timer callback
                            context.evaluateScript("void 0;")
                        }
                        context.virtualMachine.removeManagedReference(firedRef, withOwner: context)
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                // Attach the live Timer to the tombstone. A `clearTimeout` racing in
                // between leaves no entry to attach to, and the fire guard above then
                // swallows the callback — worst case is one harmless no-op firing.
                stateQueue.sync { timers[timerId]?.timer = timer }
            }

            return JSValue(object: timerId, in: context)
        }

        // clearTimeout(timerId)
        let clearTimeout: @convention(block) (JSValue) -> Void = { [weak runtime] timerId in
            guard let runtime = runtime, let context = runtime.context else { return }
            guard let id = timerId.toString() else { return }
            let entry: TimerEntry? = stateQueue.sync {
                return timers.removeValue(forKey: id)
            }
            if let entry = entry {
                // Remove the managed reference so the JSValue can be GC'd
                context.virtualMachine.removeManagedReference(entry.callbackRef, withOwner: context)
                // Timer invalidation must happen on the main thread where it was
                // created. A tombstone has no Timer yet — removing the entry is enough,
                // because the pending main-queue block arms nothing once it is gone.
                if let timer = entry.timer {
                    DispatchQueue.main.async {
                        timer.invalidate()
                    }
                }
            }
        }

        // setInterval(callback, delay) -> timerId (String)
        let setInterval: @convention(block) (JSValue, JSValue) -> JSValue = { [weak runtime] callback, delay in
            guard let runtime = runtime, let context = runtime.context else {
                return JSValue(nullIn: JSContext.current())
            }

            let delayMs = delay.isUndefined ? 0.0 : delay.toDouble()
            let timerId: String = stateQueue.sync {
                let id = String(nextTimerId)
                nextTimerId += 1
                return id
            }

            let callbackRef = JSManagedValue(value: callback)
            context.virtualMachine.addManagedReference(callbackRef, withOwner: context)

            // Reserve the ID synchronously, exactly as `setTimeout` does, so a
            // `clearInterval` in the same tick is honoured. This path was worse than
            // `setTimeout`'s: it stored unconditionally, so a same-tick clear was
            // discarded and the interval repeated forever with no way to stop it.
            stateQueue.sync {
                timers[timerId] = TimerEntry(timer: nil, callbackRef: callbackRef)
            }

            DispatchQueue.main.async {
                let stillPending: Bool = stateQueue.sync { timers[timerId] != nil }
                guard stillPending else { return }

                let timer = Timer.scheduledTimer(withTimeInterval: max(delayMs / 1000.0, 0.001), repeats: true) { [weak runtime] _ in
                    guard let runtime = runtime else { return }
                    runtime.jsQueue.async { [weak runtime] in
                        guard let runtime = runtime, let context = runtime.context else { return }
                        // If the interval was cleared, do not invoke the callback. The
                        // entry stays in the map — an interval repeats until cleared.
                        let intervalRef: JSManagedValue? = stateQueue.sync { timers[timerId]?.callbackRef }
                        guard let intervalRef else { return }
                        if let cb = intervalRef.value, !cb.isUndefined {
                            cb.call(withArguments: [])
                            context.evaluateScript("void 0;")
                        }
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                stateQueue.sync { timers[timerId]?.timer = timer }
            }

            return JSValue(object: timerId, in: context)
        }

        // clearInterval(timerId)
        let clearInterval: @convention(block) (JSValue) -> Void = { [weak runtime] timerId in
            guard let runtime = runtime, let context = runtime.context else { return }
            guard let id = timerId.toString() else { return }
            let entry: TimerEntry? = stateQueue.sync {
                return timers.removeValue(forKey: id)
            }
            if let entry = entry {
                // Remove the managed reference so the JSValue can be GC'd
                context.virtualMachine.removeManagedReference(entry.callbackRef, withOwner: context)
                // Invalidate the timer on the main thread where it was scheduled. A
                // tombstone has no Timer yet; its pending block arms nothing.
                if let timer = entry.timer {
                    DispatchQueue.main.async {
                        timer.invalidate()
                    }
                }
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

            let rafId: String = stateQueue.sync {
                let id = String(nextRafId)
                nextRafId += 1
                // Store the callback in our dictionary. The strong reference from Swift
                // prevents JSC from garbage collecting it until we remove it.
                rafCallbacks[id] = callback
                return id
            }

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
            stateQueue.async { rafCallbacks.removeValue(forKey: id) }
        }

        context.setObject(requestAnimationFrame, forKeyedSubscript: "requestAnimationFrame" as NSString)
        context.setObject(cancelAnimationFrame, forKeyedSubscript: "cancelAnimationFrame" as NSString)
    }

    /// Called from the display link target on every frame.
    /// Dispatches all pending RAF callbacks to the JS queue.
    fileprivate static func fireRAFCallbacks(runtime: JSRuntime, timestamp: Double) {
        // Snapshot and clear callbacks under the lock (RAF is one-shot)
        let callbacks: [String: JSValue] = stateQueue.sync {
            let snapshot = rafCallbacks
            rafCallbacks.removeAll()
            return snapshot
        }

        guard !callbacks.isEmpty else {
            // No pending callbacks — stop the display link
            displayLink?.invalidate()
            displayLink = nil
            return
        }

        runtime.jsQueue.async { [weak runtime] in
            guard let runtime = runtime, let context = runtime.context else { return }

            for (_, callback) in callbacks where !callback.isUndefined {
                callback.call(withArguments: [timestamp])
            }

            // Drain microtasks after all RAF callbacks
            context.evaluateScript("void 0;")

            // If no more callbacks pending, stop the display link
            let isEmpty: Bool = stateQueue.sync { rafCallbacks.isEmpty }
            if isEmpty {
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

        guard let perfObj = context.objectForKeyedSubscript("performance") else {
            NSLog("[VueNative] Warning: failed to get performance object")
            return
        }
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

    // BASELINE: one closure registers the whole `fetch` surface (request building,
    // promise capture, response shaping). Splitting it means threading a dozen locals
    // through helpers; tracked as a refactor, not a defect.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
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
                return context.evaluateScript("Promise.reject(new TypeError('Invalid URL'))") ?? JSValue(undefinedIn: context)
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
                   !body.isUndefined, !body.isNull {
                    // `body.toString()` stringifies *anything*, so a `FormData`
                    // silently became "[object FormData]" and an `ArrayBuffer` became
                    // "[object ArrayBuffer]". The request still went out, with garbage
                    // in the body and a Content-Type that did not match. Reject
                    // explicitly instead: a loud TypeError at the call site beats a
                    // corrupt request the server rejects with an opaque 400.
                    if let unsupported = unsupportedBodyKind(body) {
                        let message = "fetch: \(unsupported) request bodies are not supported; serialize to a string first (JSON.stringify, or URLSearchParams.toString())"
                        return context.evaluateScript(
                            "Promise.reject(new TypeError(\(JSPolyfillsJSON.encode(message))))"
                        ) ?? JSValue(undefinedIn: context)
                    }
                    if let bodyStr = body.toString() {
                        request.httpBody = bodyStr.data(using: .utf8)
                    }
                }
            } else {
                request.httpMethod = "GET"
            }

            // Create a Promise via JS with captured resolve/reject.
            //
            // Both handlers are wrapped in `JSManagedValue` before they leave the JS
            // queue. The `dataTask` completion below runs on a URLSession delegate
            // thread and only hops to `jsQueue` afterwards, so a raw `JSValue` captured
            // here would be retained — and later dereferenced — off the JS thread.
            // AGENTS.md forbids exactly that; the timer polyfills in this file already
            // use `JSManagedValue` for the same reason.
            var capturedResolve: JSManagedValue?
            var capturedReject: JSManagedValue?

            let captureExecutor: @convention(block) (JSValue, JSValue) -> Void = { resolve, reject in
                // `new Promise(executor)` invokes the executor synchronously, on this
                // (JS) queue, so wrapping here is thread-correct.
                let managedResolve = JSManagedValue(value: resolve)
                let managedReject = JSManagedValue(value: reject)
                context.virtualMachine.addManagedReference(managedResolve, withOwner: context)
                context.virtualMachine.addManagedReference(managedReject, withOwner: context)
                capturedResolve = managedResolve
                capturedReject = managedReject
            }

            let promiseCtor = context.evaluateScript("""
                (function(executor) {
                    return new Promise(executor);
                })
            """)
            let captureBlock = JSValue(object: captureExecutor as AnyObject, in: context)
            let promise = promiseCtor?.call(withArguments: [captureBlock as Any])

            // Copy into immutable locals so the network completion captures `let`s
            // rather than the mutable boxes above, which are written on the JS queue
            // and would otherwise be read from a URLSession thread.
            guard let resolveRef = capturedResolve, let rejectRef = capturedReject else {
                if let partial = capturedResolve ?? capturedReject {
                    context.virtualMachine.removeManagedReference(partial, withOwner: context)
                }
                return context.evaluateScript(
                    "Promise.reject(new Error('fetch: failed to capture promise handlers'))"
                ) ?? JSValue(undefinedIn: context)
            }

            // When any host is pinned, the delegate-backed session must own the
            // initial request so cross-host redirects cannot bypass pinning.
            let urlSession = CertificatePinning.shared.requestSession

            let task = urlSession.dataTask(with: request) { [weak runtime] data, response, error in
                guard let runtime = runtime else { return }
                runtime.jsQueue.async { [weak runtime] in
                    guard runtime != nil, let context = runtime?.context else { return }

                    // Release both managed references on every exit path. A URLSession
                    // task always completes (success, failure, or cancellation-as-failure),
                    // so this is what stops a finished request from pinning the Promise's
                    // handlers for the remaining lifetime of the context.
                    defer {
                        context.virtualMachine.removeManagedReference(resolveRef, withOwner: context)
                        context.virtualMachine.removeManagedReference(rejectRef, withOwner: context)
                    }

                    if let error = error {
                        let errMsg = error.localizedDescription
                        if let reject = rejectRef.value, !reject.isUndefined {
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
                    if let resolve = resolveRef.value, !resolve.isUndefined {
                        guard let responseObj = JSValue(newObjectIn: context) else {
                            NSLog("[VueNative] Warning: failed to create response object")
                            return
                        }
                        responseObj.setObject(status, forKeyedSubscript: "status" as NSString)
                        responseObj.setObject(ok, forKeyedSubscript: "ok" as NSString)
                        responseObj.setObject(bodyString, forKeyedSubscript: "_body" as NSString)

                        // headers object
                        if let headersObj = JSValue(newObjectIn: context) {
                            for (k, v) in headersDict {
                                headersObj.setObject(v, forKeyedSubscript: k as NSString)
                            }
                            responseObj.setObject(headersObj, forKeyedSubscript: "headers" as NSString)
                        }

                        // .text() method
                        let bodyStringCopy = bodyString
                        let textMethod: @convention(block) () -> JSValue = {
                            return context.evaluateScript("Promise.resolve(\(JSPolyfillsJSON.encode(bodyStringCopy)))") ?? JSValue(undefinedIn: context)
                        }
                        responseObj.setObject(textMethod, forKeyedSubscript: "text" as NSString)

                        // .json() method
                        let jsonMethod: @convention(block) () -> JSValue = {
                            return context.evaluateScript("(function(s){ try { return Promise.resolve(JSON.parse(s)); } catch(e) { return Promise.reject(e); } })(\(JSPolyfillsJSON.encode(bodyStringCopy)))") ?? JSValue(undefinedIn: context)
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

    /// Name of a request-body type this `fetch` cannot serialize, or `nil` when
    /// `toString()` represents the value faithfully.
    ///
    /// Strings and numbers stringify to themselves, and `URLSearchParams.toString()`
    /// is exactly the encoded form the request needs, so those are allowed through.
    /// Everything binary or multipart is not: `toString()` on them yields
    /// `"[object FormData]"` and friends, which would be sent as the body.
    ///
    /// MUST be called on the JS queue — it reads properties off a live `JSValue`.
    private static func unsupportedBodyKind(_ body: JSValue) -> String? {
        guard body.isObject else { return nil }

        // ArrayBufferView subtypes (Uint8Array, DataView, …) have no stable
        // constructor name across engines, so detect them structurally first.
        // `forProperty` returns an implicitly-unwrapped optional, so compare against
        // `false` rather than force-touching it.
        if body.forProperty("BYTES_PER_ELEMENT")?.isUndefined == false { return "TypedArray" }
        if body.forProperty("buffer")?.isUndefined == false { return "ArrayBufferView" }

        switch body.forProperty("constructor")?.forProperty("name")?.toString() ?? "" {
        case "FormData": return "FormData"
        case "Blob": return "Blob"
        case "File": return "File"
        case "ArrayBuffer": return "ArrayBuffer"
        default: return nil
        }
    }

    // MARK: - atob / btoa (Base64)

    private static func registerBase64(in context: JSContext) {
        // atob — decode a base64-encoded string
        let atob: @convention(block) (String) -> String = { encoded in
            guard let data = Data(base64Encoded: encoded) else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
        }
        context.setObject(atob, forKeyedSubscript: "atob" as NSString)

        // btoa — encode a string to base64
        let btoa: @convention(block) (String) -> String = { str in
            guard let data = str.data(using: .utf8) else { return "" }
            return data.base64EncodedString()
        }
        context.setObject(btoa, forKeyedSubscript: "btoa" as NSString)
    }

    // MARK: - TextEncoder / TextDecoder

    private static func registerTextEncoding(in context: JSContext) {
        context.evaluateScript("""
            class TextEncoder {
                constructor(encoding = 'utf-8') { this.encoding = encoding; }
                encode(str) {
                    const arr = [];
                    for (let i = 0; i < str.length; i++) {
                        let c = str.charCodeAt(i);
                        if (c < 0x80) { arr.push(c); }
                        else if (c < 0x800) { arr.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f)); }
                        else if (c < 0xd800 || c >= 0xe000) { arr.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f)); }
                        else { i++; c = 0x10000 + (((c & 0x3ff) << 10) | (str.charCodeAt(i) & 0x3ff)); arr.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 0x3f), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f)); }
                    }
                    return new Uint8Array(arr);
                }
            }
            class TextDecoder {
                constructor(encoding = 'utf-8') { this.encoding = encoding; }
                decode(buffer) {
                    const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
                    let result = '';
                    for (let i = 0; i < bytes.length;) {
                        let c = bytes[i++];
                        if (c < 0x80) { result += String.fromCharCode(c); }
                        else if (c < 0xe0) { result += String.fromCharCode(((c & 0x1f) << 6) | (bytes[i++] & 0x3f)); }
                        else if (c < 0xf0) { result += String.fromCharCode(((c & 0x0f) << 12) | ((bytes[i++] & 0x3f) << 6) | (bytes[i++] & 0x3f)); }
                        else { const cp = ((c & 0x07) << 18) | ((bytes[i++] & 0x3f) << 12) | ((bytes[i++] & 0x3f) << 6) | (bytes[i++] & 0x3f); result += String.fromCodePoint(cp); }
                    }
                    return result;
                }
            }
            globalThis.TextEncoder = TextEncoder;
            globalThis.TextDecoder = TextDecoder;
        """)
    }

    // MARK: - URL / URLSearchParams

    private static func registerURL(in context: JSContext) {
        context.evaluateScript("""
            if (typeof URL === 'undefined') {
                class URL {
                    constructor(url, base) {
                        if (base) {
                            if (!url.match(/^[a-zA-Z]+:/)) {
                                const b = new URL(base);
                                url = b.origin + (url.startsWith('/') ? '' : '/') + url;
                            }
                        }
                        const match = url.match(/^([a-zA-Z]+:)\\/\\/([^/:]+)(:\\d+)?(\\/[^?#]*)?(\\?[^#]*)?(#.*)?$/);
                        if (!match) { this.href = url; this.protocol = ''; this.host = ''; this.hostname = ''; this.port = ''; this.pathname = '/'; this.search = ''; this.hash = ''; this.origin = ''; this.searchParams = new URLSearchParams(''); return; }
                        this.protocol = match[1] || '';
                        this.hostname = match[2] || '';
                        this.port = (match[3] || '').slice(1);
                        this.host = this.hostname + (this.port ? ':' + this.port : '');
                        this.pathname = match[4] || '/';
                        this.search = match[5] || '';
                        this.hash = match[6] || '';
                        this.origin = this.protocol + '//' + this.host;
                        this.href = url;
                        this.searchParams = new URLSearchParams(this.search);
                    }
                    toString() { return this.href; }
                }
                globalThis.URL = URL;
            }
            if (typeof URLSearchParams === 'undefined') {
                class URLSearchParams {
                    constructor(init) {
                        this._params = [];
                        if (typeof init === 'string') {
                            init.replace(/^\\?/, '').split('&').filter(Boolean).forEach(p => {
                                const [k, ...v] = p.split('=');
                                this._params.push([decodeURIComponent(k), decodeURIComponent(v.join('='))]);
                            });
                        }
                    }
                    get(name) { const p = this._params.find(([k]) => k === name); return p ? p[1] : null; }
                    getAll(name) { return this._params.filter(([k]) => k === name).map(([,v]) => v); }
                    has(name) { return this._params.some(([k]) => k === name); }
                    set(name, value) { this.delete(name); this._params.push([name, String(value)]); }
                    append(name, value) { this._params.push([name, String(value)]); }
                    delete(name) { this._params = this._params.filter(([k]) => k !== name); }
                    toString() { return this._params.map(([k, v]) => encodeURIComponent(k) + '=' + encodeURIComponent(v)).join('&'); }
                    forEach(cb) { this._params.forEach(([k, v]) => cb(v, k, this)); }
                    entries() { return this._params[Symbol.iterator](); }
                    keys() { return this._params.map(([k]) => k)[Symbol.iterator](); }
                    values() { return this._params.map(([,v]) => v)[Symbol.iterator](); }
                    [Symbol.iterator]() { return this.entries(); }
                }
                globalThis.URLSearchParams = URLSearchParams;
            }
        """)
    }

    // MARK: - crypto.getRandomValues

    /// Upper bound on the byte length `crypto.getRandomValues` will fill.
    ///
    /// The length comes straight from JS. Uncapped, `new Uint8Array(1e9)` asks for a
    /// gigabyte of Swift storage *and* a billion separate JavaScriptCore bridge
    /// calls to write it back, which iOS kills via jetsam — a remote page could
    /// therefore take the whole app down. 65536 is the quota the web platform
    /// specifies; browsers throw `QuotaExceededError` above it.
    static let maxRandomBytes: Int32 = 65536

    private static func registerCrypto(in context: JSContext) {
        // Native callback using SecRandomCopyBytes for cryptographic randomness
        let cryptoGetRandomValues: @convention(block) (JSValue) -> JSValue = { typedArray in
            let jsContext = JSContext.current()
            // `forProperty` returns an implicitly-unwrapped optional; a call with no
            // argument (or a non-object) must not crash here.
            guard let lengthValue = typedArray.forProperty("length"),
                  !lengthValue.isUndefined, !lengthValue.isNull else {
                return typedArray
            }
            let length = lengthValue.toInt32()

            guard length > 0 else { return typedArray }

            guard length <= maxRandomBytes else {
                jsContext?.exception = JSValue(
                    newErrorFromMessage: "QuotaExceededError: crypto.getRandomValues cannot fill \(length) bytes; the limit is \(maxRandomBytes)",
                    in: jsContext
                )
                return JSValue(undefinedIn: jsContext)
            }

            var bytes = [UInt8](repeating: 0, count: Int(length))
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

            // The return status must not be discarded. Callers use this for tokens,
            // nonces, IVs and key material, so on failure JS would silently receive
            // an all-zero buffer — indistinguishable from success, and a
            // key/nonce-reuse vulnerability rather than a degraded UI. Fail loudly.
            guard status == errSecSuccess else {
                // `bytes` is discarded here without being written back, so JS never
                // sees the partially-filled (or all-zero) buffer.
                jsContext?.exception = JSValue(
                    newErrorFromMessage: "crypto.getRandomValues: SecRandomCopyBytes failed with OSStatus \(status)",
                    in: jsContext
                )
                return JSValue(undefinedIn: jsContext)
            }

            for i in 0..<Int(length) {
                typedArray.setValue(bytes[i], at: i)
            }
            return typedArray
        }

        // Ensure the crypto global object exists
        context.evaluateScript("""
            if (typeof crypto === 'undefined') {
                globalThis.crypto = {};
            }
        """)

        if let cryptoObj = context.objectForKeyedSubscript("crypto") {
            cryptoObj.setObject(cryptoGetRandomValues, forKeyedSubscript: "getRandomValues" as NSString)
        }
    }
}

// MARK: - JSON encode helper

/// Produce a JSON-safe string literal (with quotes) for embedding in JS eval strings.
private enum JSPolyfillsJSON {
    static func encode(_ str: String) -> String {
        // Wrap in array so JSONSerialization gets a valid top-level type.
        // String alone causes an NSException that try? cannot catch.
        if let data = try? JSONSerialization.data(withJSONObject: [str]),
           let json = String(data: data, encoding: .utf8),
           json.count >= 2 {
            return String(json.dropFirst().dropLast())
        }
        // Fallback: manual escaping
        let escaped = str
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
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
