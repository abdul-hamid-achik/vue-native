import JavaScriptCore
import AppKit
import Security

/// Registers browser-like APIs in JSContext that the Vue runtime and application code expect.
/// macOS port of the iOS JSPolyfills. All callbacks execute on the JS queue unless noted.
enum JSPolyfills {

    // MARK: - Timer storage

    private struct TimerEntry {
        let timer: Timer
        let callbackRef: JSManagedValue?
    }

    private static let stateQueue = DispatchQueue(label: "com.vuenative.macos.polyfills.state")
    private static var timers: [String: TimerEntry] = [:]
    private static var nextTimerId: Int = 1

    // MARK: - RAF storage

    private static var displayLink: CVDisplayLink?
    private static var displayLinkSource: DispatchSourceUserDataAdd?
    private static var displayLinkSourcePtr: UnsafeMutableRawPointer?
    private static var rafCallbacks: [String: JSValue] = [:]
    private static var nextRafId: Int = 1
    private static weak var rafRuntime: JSRuntime?

    // MARK: - Reset

    static func reset() {
        let oldTimers: [String: TimerEntry] = stateQueue.sync {
            let snapshot = timers
            timers.removeAll()
            rafCallbacks.removeAll()
            nextTimerId = 1
            nextRafId = 1
            return snapshot
        }

        DispatchQueue.main.async {
            for (_, entry) in oldTimers {
                entry.timer.invalidate()
            }
            if let link = displayLink {
                CVDisplayLinkStop(link)
            }
            displayLink = nil
            displayLinkSource?.cancel()
            displayLinkSource = nil
            if let ptr = displayLinkSourcePtr {
                Unmanaged<AnyObject>.fromOpaque(ptr).release()
                displayLinkSourcePtr = nil
            }
            rafRuntime = nil
        }
    }

    // MARK: - Registration

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
        context.evaluateScript("var console = {};")

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
            NSLog("[VueNative macOS] Warning: failed to get console object")
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

            let callbackRef = JSManagedValue(value: callback)
            context.virtualMachine.addManagedReference(callbackRef, withOwner: context)

            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: max(delayMs / 1000.0, 0.001), repeats: false) { [weak runtime] _ in
                    guard let runtime = runtime else { return }
                    runtime.jsQueue.async { [weak runtime] in
                        guard let runtime = runtime, let context = runtime.context else { return }
                        let stillActive: Bool = stateQueue.sync {
                            guard timers[timerId] != nil else { return false }
                            timers.removeValue(forKey: timerId)
                            return true
                        }
                        guard stillActive else { return }
                        if let cb = callbackRef?.value, !cb.isUndefined {
                            cb.call(withArguments: [])
                            context.evaluateScript("void 0;")
                        }
                        context.virtualMachine.removeManagedReference(callbackRef, withOwner: context)
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                stateQueue.async {
                    if timers[timerId] == nil {
                        timers[timerId] = TimerEntry(timer: timer, callbackRef: callbackRef)
                    }
                }
            }

            return JSValue(object: timerId, in: context)
        }

        let clearTimeout: @convention(block) (JSValue) -> Void = { [weak runtime] timerId in
            guard let runtime = runtime, let context = runtime.context else { return }
            guard let id = timerId.toString() else { return }
            let entry: TimerEntry? = stateQueue.sync {
                return timers.removeValue(forKey: id)
            }
            if let entry = entry {
                context.virtualMachine.removeManagedReference(entry.callbackRef, withOwner: context)
                DispatchQueue.main.async {
                    entry.timer.invalidate()
                }
            }
        }

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

        let clearInterval: @convention(block) (JSValue) -> Void = { [weak runtime] timerId in
            guard let runtime = runtime, let context = runtime.context else { return }
            guard let id = timerId.toString() else { return }
            let entry: TimerEntry? = stateQueue.sync {
                return timers.removeValue(forKey: id)
            }
            if let entry = entry {
                context.virtualMachine.removeManagedReference(entry.callbackRef, withOwner: context)
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
        context.evaluateScript("""
            function queueMicrotask(callback) {
                Promise.resolve().then(callback);
            }
        """)
    }

    // MARK: - requestAnimationFrame / cancelAnimationFrame

    private static func registerRAF(in context: JSContext, runtime: JSRuntime) {

        let requestAnimationFrame: @convention(block) (JSValue) -> JSValue = { [weak runtime] callback in
            guard let runtime = runtime, let context = runtime.context else {
                return JSValue(nullIn: JSContext.current())
            }

            let rafId: String = stateQueue.sync {
                let id = String(nextRafId)
                nextRafId += 1
                rafCallbacks[id] = callback
                return id
            }

            // Ensure CVDisplayLink is running
            DispatchQueue.main.async {
                if displayLink == nil {
                    rafRuntime = runtime
                    startDisplayLink(runtime: runtime)
                }
            }

            return JSValue(object: rafId, in: context)
        }

        let cancelAnimationFrame: @convention(block) (JSValue) -> Void = { [weak runtime] rafId in
            _ = runtime
            guard let id = rafId.toString() else { return }
            stateQueue.async { rafCallbacks.removeValue(forKey: id) }
        }

        context.setObject(requestAnimationFrame, forKeyedSubscript: "requestAnimationFrame" as NSString)
        context.setObject(cancelAnimationFrame, forKeyedSubscript: "cancelAnimationFrame" as NSString)
    }

    /// Start a CVDisplayLink for requestAnimationFrame on macOS.
    /// CVDisplayLink fires on a background thread, so we use a DispatchSource
    /// to coalesce signals and dispatch to the JS queue.
    private static func startDisplayLink(runtime: JSRuntime) {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link = link else { return }

        let source = DispatchSourceMakeUserDataAdd()
        displayLinkSource = source

        source.setEventHandler { [weak runtime] in
            guard let runtime = runtime else { return }
            let timestamp = CACurrentMediaTime() * 1000.0
            fireRAFCallbacks(runtime: runtime, timestamp: timestamp)
        }
        source.resume()

        // Wrap the DispatchSource in an Unmanaged pointer so the C callback
        // can access it without capturing context (C function pointers cannot
        // capture Swift closures).
        let sourcePtr = Unmanaged.passRetained(source as AnyObject).toOpaque()
        displayLinkSourcePtr = sourcePtr

        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, userInfo -> CVReturn in
            guard let userInfo = userInfo else { return kCVReturnSuccess }
            let src = Unmanaged<AnyObject>.fromOpaque(userInfo).takeUnretainedValue()
            (src as? DispatchSourceUserDataAdd)?.add(data: 1)
            return kCVReturnSuccess
        }, sourcePtr)

        CVDisplayLinkStart(link)
        displayLink = link
    }

    /// Fire all pending RAF callbacks. RAF is one-shot.
    fileprivate static func fireRAFCallbacks(runtime: JSRuntime, timestamp: Double) {
        let callbacks: [String: JSValue] = stateQueue.sync {
            let snapshot = rafCallbacks
            rafCallbacks.removeAll()
            return snapshot
        }

        guard !callbacks.isEmpty else {
            // No pending callbacks -- stop the display link
            DispatchQueue.main.async {
                if let link = displayLink {
                    CVDisplayLinkStop(link)
                }
                displayLink = nil
                displayLinkSource?.cancel()
                displayLinkSource = nil
            }
            return
        }

        runtime.jsQueue.async { [weak runtime] in
            guard let runtime = runtime, let context = runtime.context else { return }

            for (_, callback) in callbacks {
                if !callback.isUndefined {
                    callback.call(withArguments: [timestamp])
                }
            }

            context.evaluateScript("void 0;")

            let isEmpty: Bool = stateQueue.sync { rafCallbacks.isEmpty }
            if isEmpty {
                DispatchQueue.main.async {
                    if let link = displayLink {
                        CVDisplayLinkStop(link)
                    }
                    displayLink = nil
                    displayLinkSource?.cancel()
                    displayLinkSource = nil
                }
            }
        }
    }

    // MARK: - performance.now()

    private static func registerPerformance(in context: JSContext, runtime: JSRuntime) {
        context.evaluateScript("var performance = {};")

        let performanceNow: @convention(block) () -> Double = { [weak runtime] in
            guard let runtime = runtime else { return 0 }
            return (CFAbsoluteTimeGetCurrent() - runtime.startTime) * 1000.0
        }

        guard let perfObj = context.objectForKeyedSubscript("performance") else {
            NSLog("[VueNative macOS] Warning: failed to get performance object")
            return
        }
        perfObj.setObject(performanceNow, forKeyedSubscript: "now" as NSString)
    }

    // MARK: - globalThis

    private static func registerGlobalThis(in context: JSContext) {
        context.evaluateScript("""
            if (typeof globalThis === 'undefined') {
                var globalThis = this;
            }
        """)
    }

    // MARK: - fetch

    private static func registerFetch(in context: JSContext, runtime: JSRuntime) {
        let fetch: @convention(block) (JSValue, JSValue) -> JSValue = { [weak runtime] urlValue, optionsValue in
            guard let runtime = runtime, let context = runtime.context else {
                return JSValue(undefinedIn: JSContext.current())
            }

            let urlString = urlValue.toString() ?? ""
            guard let url = URL(string: urlString) else {
                return context.evaluateScript("Promise.reject(new TypeError('Invalid URL'))") ?? JSValue(undefinedIn: context)
            }

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

            let task = URLSession.shared.dataTask(with: request) { [weak runtime] data, response, error in
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

                    var headersDict: [String: String] = [:]
                    if let httpResp = httpResponse {
                        for (k, v) in httpResp.allHeaderFields {
                            headersDict["\(k)"] = "\(v)"
                        }
                    }

                    if let resolve = resolveRef, !resolve.isUndefined {
                        guard let responseObj = JSValue(newObjectIn: context) else {
                            NSLog("[VueNative macOS] Warning: failed to create response object")
                            return
                        }
                        responseObj.setObject(status, forKeyedSubscript: "status" as NSString)
                        responseObj.setObject(ok, forKeyedSubscript: "ok" as NSString)
                        responseObj.setObject(bodyString, forKeyedSubscript: "_body" as NSString)

                        if let headersObj = JSValue(newObjectIn: context) {
                            for (k, v) in headersDict {
                                headersObj.setObject(v, forKeyedSubscript: k as NSString)
                            }
                            responseObj.setObject(headersObj, forKeyedSubscript: "headers" as NSString)
                        }

                        let bodyStringCopy = bodyString
                        let textMethod: @convention(block) () -> JSValue = {
                            return context.evaluateScript("Promise.resolve(\(JSPolyfillsJSON.encode(bodyStringCopy)))") ?? JSValue(undefinedIn: context)
                        }
                        responseObj.setObject(textMethod, forKeyedSubscript: "text" as NSString)

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

    // MARK: - atob / btoa (Base64)

    private static func registerBase64(in context: JSContext) {
        let atob: @convention(block) (String) -> String = { encoded in
            guard let data = Data(base64Encoded: encoded) else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
        }
        context.setObject(atob, forKeyedSubscript: "atob" as NSString)

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

private enum JSPolyfillsJSON {
    static func encode(_ str: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: [str]),
           let json = String(data: data, encoding: .utf8),
           json.count >= 2 {
            return String(json.dropFirst().dropLast())
        }
        let escaped = str
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }
}

// MARK: - DispatchSource helper

/// Creates a DispatchSourceUserDataAdd on the main queue for coalescing CVDisplayLink signals.
private func DispatchSourceMakeUserDataAdd() -> DispatchSourceUserDataAdd {
    return DispatchSource.makeUserDataAddSource(queue: .main)
}
