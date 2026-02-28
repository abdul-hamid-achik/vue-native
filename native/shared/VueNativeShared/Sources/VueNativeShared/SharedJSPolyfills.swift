import JavaScriptCore
import Security
import Foundation

/// Registers browser-like APIs in JSContext that the Vue runtime and application code expect.
/// All callbacks execute on the JS queue (not the main thread) unless noted otherwise.
///
/// This shared version registers everything EXCEPT requestAnimationFrame/cancelAnimationFrame,
/// which are platform-specific (CADisplayLink on iOS, CVDisplayLink/CADisplayLink on macOS).
/// Each platform adds its own RAF registration after calling `SharedJSPolyfills.register(in:)`.
public enum SharedJSPolyfills {

    // MARK: - Timer storage

    /// Holds a scheduled Timer alongside its JSManagedValue so both can be cleaned up together.
    private struct TimerEntry {
        let timer: Timer
        let callbackRef: JSManagedValue?
    }

    /// Serial queue that guards all mutable timer state.
    /// Timer callbacks fire on the main thread and clear/read `timers`;
    /// JS queue closures also mutate `timers` (via setTimeout/clearTimeout).
    /// This queue serializes all access to prevent data races.
    private static let stateQueue = DispatchQueue(label: "com.vuenative.polyfills.state")

    /// Active timers, keyed by string ID. Access ONLY via `stateQueue`.
    private static var timers: [String: TimerEntry] = [:]
    /// Next timer ID counter. Access ONLY via `stateQueue`.
    private static var nextTimerId: Int = 1

    // MARK: - RAF storage (managed by platform-specific code)

    /// Pending requestAnimationFrame callbacks. Access ONLY via `stateQueue`.
    public private(set) static var rafCallbacks: [String: JSValue] = [:]
    /// Next RAF ID counter. Access ONLY via `stateQueue`.
    public private(set) static var nextRafId: Int = 1

    /// Atomically allocate a RAF ID and store the callback. Returns the ID string.
    /// Platform-specific RAF registration uses this to store callbacks.
    public static func storeRAFCallback(_ callback: JSValue) -> String {
        return stateQueue.sync {
            let id = String(nextRafId)
            nextRafId += 1
            rafCallbacks[id] = callback
            return id
        }
    }

    /// Remove a RAF callback by ID. Returns true if it was present.
    @discardableResult
    public static func removeRAFCallback(_ id: String) -> Bool {
        return stateQueue.sync {
            return rafCallbacks.removeValue(forKey: id) != nil
        }
    }

    /// Snapshot and clear all pending RAF callbacks (one-shot semantics).
    /// Platform-specific display link handlers call this each frame.
    public static func drainRAFCallbacks() -> [String: JSValue] {
        return stateQueue.sync {
            let snapshot = rafCallbacks
            rafCallbacks.removeAll()
            return snapshot
        }
    }

    /// Returns true if there are pending RAF callbacks.
    public static var hasRAFCallbacks: Bool {
        return stateQueue.sync { !rafCallbacks.isEmpty }
    }

    // MARK: - Reset

    /// Reset all polyfill state. Call before creating a fresh JSContext on hot reload.
    /// Safe to call from any thread — synchronizes internally via `stateQueue`.
    /// NOTE: Does NOT touch display links — those are platform-specific.
    /// Each platform must invalidate its own display link separately.
    public static func reset() {
        // Snapshot and clear timer/RAF state under the lock
        let oldTimers: [String: TimerEntry] = stateQueue.sync {
            let snapshot = timers
            timers.removeAll()
            rafCallbacks.removeAll()
            nextTimerId = 1
            nextRafId = 1
            return snapshot
        }

        // Invalidate timers on the main thread (where they were scheduled)
        DispatchQueue.main.async {
            for (_, entry) in oldTimers {
                entry.timer.invalidate()
            }
        }
    }

    // MARK: - Registration

    /// Register all shared polyfills into the given JSRuntime's context.
    /// MUST be called on the JS queue.
    /// Does NOT register requestAnimationFrame — each platform adds that separately.
    public static func register(in runtime: JSRuntime) {
        guard let context = runtime.context else { return }

        registerConsole(in: context)
        registerTimers(in: context, runtime: runtime)
        registerMicrotask(in: context)
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

            // Schedule timer on the main thread RunLoop, then dispatch callback to JS queue
            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: max(delayMs / 1000.0, 0.001), repeats: false) { [weak runtime] _ in
                    guard let runtime = runtime else { return }
                    runtime.jsQueue.async { [weak runtime] in
                        guard let runtime = runtime, let context = runtime.context else { return }
                        // Timer already fired — only invoke if not cleared
                        let stillActive: Bool = stateQueue.sync {
                            guard timers[timerId] != nil else { return false }
                            timers.removeValue(forKey: timerId)
                            return true
                        }
                        guard stillActive else { return }
                        if let cb = callbackRef?.value, !cb.isUndefined {
                            cb.call(withArguments: [])
                            // Drain microtasks after timer callback
                            context.evaluateScript("void 0;")
                        }
                        context.virtualMachine.removeManagedReference(callbackRef, withOwner: context)
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                stateQueue.async {
                    // Only store if not already cleared before the timer was created
                    if timers[timerId] == nil {
                        timers[timerId] = TimerEntry(timer: timer, callbackRef: callbackRef)
                    }
                }
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
                // Timer invalidation must happen on the main thread where it was created
                DispatchQueue.main.async {
                    entry.timer.invalidate()
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

            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: max(delayMs / 1000.0, 0.001), repeats: true) { [weak runtime] _ in
                    guard let runtime = runtime else { return }
                    runtime.jsQueue.async { [weak runtime] in
                        guard let runtime = runtime, let context = runtime.context else { return }
                        // If the interval was cleared, do not invoke the callback
                        let stillActive: Bool = stateQueue.sync { timers[timerId] != nil }
                        guard stillActive else { return }
                        if let cb = callbackRef?.value, !cb.isUndefined {
                            cb.call(withArguments: [])
                            context.evaluateScript("void 0;")
                        }
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                stateQueue.async {
                    timers[timerId] = TimerEntry(timer: timer, callbackRef: callbackRef)
                }
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
                // Invalidate the timer on the main thread where it was scheduled
                DispatchQueue.main.async {
                    entry.timer.invalidate()
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
                            let errObj = context.evaluateScript("new Error(\(SharedJSPolyfillsJSON.encode(errMsg)))")
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
                            return context.evaluateScript("Promise.resolve(\(SharedJSPolyfillsJSON.encode(bodyStringCopy)))") ?? JSValue(undefinedIn: context)
                        }
                        responseObj.setObject(textMethod, forKeyedSubscript: "text" as NSString)

                        // .json() method
                        let jsonMethod: @convention(block) () -> JSValue = {
                            return context.evaluateScript("(function(s){ try { return Promise.resolve(JSON.parse(s)); } catch(e) { return Promise.reject(e); } })(\(SharedJSPolyfillsJSON.encode(bodyStringCopy)))") ?? JSValue(undefinedIn: context)
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

    private static func registerCrypto(in context: JSContext) {
        // Native callback using SecRandomCopyBytes for cryptographic randomness
        let cryptoGetRandomValues: @convention(block) (JSValue) -> JSValue = { typedArray in
            let length = typedArray.forProperty("length").toInt32()
            if length > 0 {
                var bytes = [UInt8](repeating: 0, count: Int(length))
                _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
                for i in 0..<Int(length) {
                    typedArray.setValue(bytes[i], at: i)
                }
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
public enum SharedJSPolyfillsJSON {
    public static func encode(_ str: String) -> String {
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
