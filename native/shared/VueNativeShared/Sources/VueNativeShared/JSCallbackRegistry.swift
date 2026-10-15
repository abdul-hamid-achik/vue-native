import JavaScriptCore

/// Keeps JS callbacks that native code will call later (timers, `fetch` handlers) alive in
/// the JS heap, reachable from the global object, and hands native code an integer id.
///
/// `JSManagedValue` + `addManagedReference(_:withOwner: context)` is NOT enough: the owner
/// must be reachable from JS for the garbage collector to keep the value, and a `JSContext`
/// is not. A collection while a request or timer was pending freed the callback, so
/// `managed.value` came back `nil` and the promise never settled / the timer never fired
/// (an intermittent hang, more likely with concurrent requests).
///
/// Every method must run on the JS queue, like any other `JSValue` access.
public enum JSCallbackRegistry {
    static let globalName = "__vnCallbacks"

    /// Install the registry in a fresh context (idempotent).
    public static func install(in context: JSContext) {
        context.evaluateScript("""
            if (!globalThis.\(globalName)) {
              globalThis.\(globalName) = (function () {
                var next = 0, held = Object.create(null);
                return {
                  put: function (v) { next += 1; held[next] = v; return next; },
                  get: function (id) { return held[id]; },
                  take: function (id) { var v = held[id]; delete held[id]; return v; },
                  drop: function (id) { delete held[id]; },
                  count: function () { return Object.keys(held).length; }
                };
              })();
            }
            """)
    }

    private static func registry(_ context: JSContext) -> JSValue? {
        let r = context.objectForKeyedSubscript(globalName)
        if r == nil || r!.isUndefined { install(in: context) }
        return context.objectForKeyedSubscript(globalName)
    }

    /// Hold `value` and return its id.
    public static func retain(_ value: JSValue, in context: JSContext) -> Int {
        Int(registry(context)?.invokeMethod("put", withArguments: [value])?.toInt32() ?? 0)
    }

    /// The held value, still held (intervals).
    public static func value(_ id: Int, in context: JSContext) -> JSValue? {
        guard let v = registry(context)?.invokeMethod("get", withArguments: [id]), !v.isUndefined else { return nil }
        return v
    }

    /// The held value, released (one-shot callbacks).
    public static func take(_ id: Int, in context: JSContext) -> JSValue? {
        guard let v = registry(context)?.invokeMethod("take", withArguments: [id]), !v.isUndefined else { return nil }
        return v
    }

    /// Release without calling.
    public static func release(_ id: Int, in context: JSContext) {
        _ = registry(context)?.invokeMethod("drop", withArguments: [id])
    }

    /// Number of held callbacks (tests).
    public static func count(in context: JSContext) -> Int {
        Int(registry(context)?.invokeMethod("count", withArguments: [])?.toInt32() ?? 0)
    }
}
