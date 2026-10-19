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

    func testPlaybackRateIsClampedAndOptional() {
        XCTAssertNil(AudioModule.playbackRate(from: [:]))
        XCTAssertNil(AudioModule.playbackRate(from: ["rate": "fast"]))
        XCTAssertEqual(AudioModule.playbackRate(from: ["rate": 1.25]), 1.25)
        XCTAssertEqual(AudioModule.playbackRate(from: ["rate": 1]), 1.0)
        XCTAssertEqual(AudioModule.playbackRate(from: ["rate": 0.1]), 0.5)
        XCTAssertEqual(AudioModule.playbackRate(from: ["rate": 9]), 2.0)
    }

    /// A remote clip that is stopped while its download is in flight must not start
    /// playing: its play() resolves as cancelled and no audio:error is emitted.
    func testStopCancelsInFlightRemotePlay() {
        let module = AudioModule(bridge: NativeBridge.shared)
        var events: [String] = []
        module.eventObserver = { name, _ in events.append(name) }
        let played = expectation(description: "play callback")
        var playResult: [String: Any]?
        var playError: String?

        // Port 1 on loopback: nothing listens, so the request is pending/failing at
        // the moment stop() runs on the next main-queue turn.
        module.invoke(method: "play", args: ["http://127.0.0.1:1/clip.mp3"]) { result, error in
            playResult = result as? [String: Any]
            playError = error
            played.fulfill()
        }
        module.invoke(method: "stop", args: []) { _, _ in }

        wait(for: [played], timeout: 5)
        XCTAssertEqual(playResult?["cancelled"] as? Bool, true)
        XCTAssertNil(playError)
        XCTAssertFalse(events.contains("audio:error"))
    }

    /// A play() that fails after the previous player was stopped must emit audio:error
    /// so the JS isPlaying flag is reset.
    func testFailedPlayEmitsAudioError() {
        let module = AudioModule(bridge: NativeBridge.shared)
        var events: [String] = []
        module.eventObserver = { name, _ in events.append(name) }
        let finished = expectation(description: "play callback")
        var playError: String?

        module.invoke(method: "play", args: ["file:///definitely/not/here.mp3"]) { _, error in
            playError = error
            finished.fulfill()
        }

        wait(for: [finished], timeout: 5)
        XCTAssertNotNil(playError)
        XCTAssertEqual(events, ["audio:error"])
    }
}
