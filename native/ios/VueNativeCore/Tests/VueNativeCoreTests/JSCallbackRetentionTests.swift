import JavaScriptCore
import VueNativeShared
import XCTest
@testable import VueNativeCore

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
        let runtime = VueNativeCore.JSRuntime.shared
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
}

final class AudioLevelTests: XCTestCase {
    func testNormalizedLevelMapsDecibelsToUnitRange() {
        XCTAssertEqual(AudioModule.normalizedLevel(power: -160), 0)
        XCTAssertEqual(AudioModule.normalizedLevel(power: -50), 0)
        XCTAssertEqual(AudioModule.normalizedLevel(power: -25), 0.5, accuracy: 0.001)
        XCTAssertEqual(AudioModule.normalizedLevel(power: 0), 1)
        XCTAssertEqual(AudioModule.normalizedLevel(power: 3), 1)
        XCTAssertEqual(AudioModule.normalizedLevel(power: -.infinity), 0)
    }
}
