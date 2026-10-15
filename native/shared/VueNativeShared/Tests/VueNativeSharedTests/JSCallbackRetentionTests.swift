import JavaScriptCore
import XCTest
@testable import VueNativeShared

/// Callbacks native code calls later (timers, fetch handlers) must survive a JS garbage
/// collection while they are pending. With `JSManagedValue` owned by the context they did not:
/// the GC freed them and the timer never fired / the fetch promise never settled.
final class JSCallbackRetentionTests: XCTestCase {

    func testRegistryHoldsValuesUntilTaken() {
        let context = JSContext()!
        JSCallbackRegistry.install(in: context)
        let fn = context.evaluateScript("(function () { return 42; })")!
        let id = JSCallbackRegistry.retain(fn, in: context)
        XCTAssertGreaterThan(id, 0)
        JSGarbageCollect(context.jsGlobalContextRef)
        XCTAssertEqual(JSCallbackRegistry.value(id, in: context)?.call(withArguments: [])?.toInt32(), 42)
        XCTAssertEqual(JSCallbackRegistry.take(id, in: context)?.call(withArguments: [])?.toInt32(), 42)
        XCTAssertNil(JSCallbackRegistry.take(id, in: context))
        let other = JSCallbackRegistry.retain(fn, in: context)
        JSCallbackRegistry.release(other, in: context)
        XCTAssertEqual(JSCallbackRegistry.count(in: context), 0)
    }

    func testTimerCallbackSurvivesGarbageCollection() {
        let fired = expectation(description: "timer fired after a GC")
        let runtime = JSRuntime.shared
        runtime.initialize {
            runtime.jsQueue.async {
                let context = runtime.context!
                let done: @convention(block) () -> Void = { fired.fulfill() }
                context.setObject(done, forKeyedSubscript: "__gcTimerDone" as NSString)
                // The only reference to the arrow function is the one native code holds.
                context.evaluateScript("setTimeout(() => __gcTimerDone(), 200);")
                // Churn the heap and collect while the timer is pending.
                context.evaluateScript("for (let i = 0; i < 20000; i++) { ({ junk: new Array(16).fill(i) }); }")
                JSGarbageCollect(context.jsGlobalContextRef)
            }
        }
        wait(for: [fired], timeout: 5)
    }

    func testFetchPromiseSettlesAfterGarbageCollection() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("vn-fetch-\(UUID().uuidString).txt")
        try "hello".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let settled = expectation(description: "fetch settled after a GC")
        let runtime = JSRuntime.shared
        var body: String?
        runtime.initialize {
            runtime.jsQueue.async {
                let context = runtime.context!
                let done: @convention(block) (JSValue) -> Void = { value in
                    body = value.toString()
                    settled.fulfill()
                }
                context.setObject(done, forKeyedSubscript: "__gcFetchDone" as NSString)
                // Nothing in JS references the promise's resolve/reject but the registry.
                context.evaluateScript("""
                    fetch(\(SharedJSPolyfillsJSON.encode(file.absoluteString)))
                      .then(function (r) { return r.text(); })
                      .then(function (t) { __gcFetchDone(t); }, function (e) { __gcFetchDone('error: ' + e); });
                    """)
                context.evaluateScript("for (let i = 0; i < 20000; i++) { ({ junk: new Array(16).fill(i) }); }")
                JSGarbageCollect(context.jsGlobalContextRef)
            }
        }
        wait(for: [settled], timeout: 5)
        XCTAssertEqual(body, "hello")
        // The handlers are released once the request completes.
        let drained = expectation(description: "registry drained")
        runtime.jsQueue.async {
            XCTAssertEqual(JSCallbackRegistry.count(in: runtime.context), 0)
            drained.fulfill()
        }
        wait(for: [drained], timeout: 5)
    }
}
