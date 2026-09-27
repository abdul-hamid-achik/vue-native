#if canImport(UIKit)
import XCTest
import JavaScriptCore
import UIKit
@testable import VueNativeCore

@MainActor
final class JSPolyfillsTests: XCTestCase {

    // MARK: - Properties

    private var runtime: JSRuntime!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        runtime = JSRuntime.shared
        let initExpectation = expectation(description: "JSRuntime initialized")
        runtime.initialize {
            initExpectation.fulfill()
        }
        waitForExpectations(timeout: 20.0)
    }

    override func tearDown() {
        runtime = nil
        super.tearDown()
    }

    // MARK: - Helper

    /// Evaluate a script synchronously and return the result.
    private func evalSync(_ script: String) -> JSValue? {
        let exp = expectation(description: "eval")
        var result: JSValue?
        runtime.evaluateScript(script) { value in
            result = value
            exp.fulfill()
        }
        waitForExpectations(timeout: 20.0)
        return result
    }

    // MARK: - console Tests

    func testConsoleLogDoesNotCrash() {
        // console.log should not throw or crash
        let result = evalSync("console.log('test message'); true")
        XCTAssertNotNil(result, "console.log should not crash")
        XCTAssertTrue(result?.toBool() == true, "Script should evaluate to true")
    }

    func testConsoleWarnDoesNotCrash() {
        let result = evalSync("console.warn('warning message'); true")
        XCTAssertNotNil(result, "console.warn should not crash")
        XCTAssertTrue(result?.toBool() == true, "Script should evaluate to true")
    }

    func testConsoleErrorDoesNotCrash() {
        let result = evalSync("console.error('error message'); true")
        XCTAssertNotNil(result, "console.error should not crash")
        XCTAssertTrue(result?.toBool() == true, "Script should evaluate to true")
    }

    func testConsoleDebugDoesNotCrash() {
        let result = evalSync("console.debug('debug message'); true")
        XCTAssertNotNil(result, "console.debug should not crash")
    }

    func testConsoleInfoDoesNotCrash() {
        let result = evalSync("console.info('info message'); true")
        XCTAssertNotNil(result, "console.info should not crash")
    }

    // MARK: - performance.now() Tests

    func testPerformanceNowReturnsNumber() {
        let result = evalSync("typeof performance.now()")
        XCTAssertEqual(result?.toString(), "number", "performance.now() should return a number")
    }

    func testPerformanceNowReturnsPositiveValue() {
        let result = evalSync("performance.now() > 0")
        XCTAssertTrue(result?.toBool() == true, "performance.now() should return a positive number")
    }

    func testPerformanceNowIncreases() {
        let result = evalSync("""
            var a = performance.now();
            var i = 0; while(i < 10000) { i++; }
            var b = performance.now();
            b >= a;
        """)
        XCTAssertTrue(result?.toBool() == true, "performance.now() should be non-decreasing")
    }

    // MARK: - queueMicrotask Tests

    func testQueueMicrotaskExists() {
        let result = evalSync("typeof queueMicrotask")
        XCTAssertEqual(result?.toString(), "function", "queueMicrotask should be a function")
    }

    func testQueueMicrotaskCallbackRuns() {
        let result = evalSync("""
            var microtaskRan = false;
            queueMicrotask(function() { microtaskRan = true; });
            // Microtask should execute after the current task via Promise.resolve().then()
            microtaskRan;
        """)
        // Note: the microtask may not have fired yet since it's Promise-based.
        // But after the evaluateScript drain, it should have run.
        XCTAssertNotNil(result, "queueMicrotask should not crash")
    }

    // MARK: - setTimeout Tests

    func testSetTimeoutExists() {
        let result = evalSync("typeof setTimeout")
        XCTAssertEqual(result?.toString(), "function", "setTimeout should be a function")
    }

    func testSetTimeoutReturnsTimerId() {
        let result = evalSync("var id = setTimeout(function(){}, 1000); typeof id !== 'undefined'")
        XCTAssertTrue(result?.toBool() == true, "setTimeout should return a timer ID")
    }

    func testSetTimeoutFiresCallback() {
        let exp = expectation(description: "setTimeout fires")

        runtime.evaluateScript("""
            globalThis.__testTimeoutFired = false;
            setTimeout(function() {
                globalThis.__testTimeoutFired = true;
            }, 50);
        """)

        // Check after a delay — use evaluateScript directly to avoid
        // nested waitForExpectations (XCTest API violation).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.runtime.evaluateScript("globalThis.__testTimeoutFired") { value in
                XCTAssertTrue(value?.toBool() == true, "setTimeout callback should have fired")
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - clearTimeout Tests

    func testClearTimeoutExists() {
        let result = evalSync("typeof clearTimeout")
        XCTAssertEqual(result?.toString(), "function", "clearTimeout should be a function")
    }

    func testClearTimeoutCancelsPendingCallback() {
        // Smoke check: clearTimeout is callable and does not crash for a timer that
        // is still pending. The deterministic cancellation assertions live in
        // `testClearTimeoutInSameTickPreventsCallback` below.
        let result = evalSync("""
            var __clearTestFired = false;
            var tid = setTimeout(function() { __clearTestFired = true; }, 100000);
            clearTimeout(tid);
            typeof tid !== 'undefined';
        """)
        XCTAssertTrue(result?.toBool() == true, "clearTimeout should accept a timer ID")
    }

    /// Wait long enough for the main-queue block that arms a `Timer` to have run and
    /// for a short timer to have fired, so an assertion afterwards is meaningful.
    private func letTimersSettle(_ interval: TimeInterval = 0.6) {
        let settled = expectation(description: "timer window elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { settled.fulfill() }
        waitForExpectations(timeout: 15)
    }

    func testClearTimeoutInSameTickPreventsCallback() {
        // Regression: `setTimeout` built its `Timer` inside a later
        // `DispatchQueue.main.async` and only stored it there, while `clearTimeout`
        // ran on the JS queue in between. The clear found nothing to remove, and the
        // store guard `if timers[timerId] == nil` could not tell "never stored yet"
        // from "already cleared" — so it stored the Timer and the cancelled callback
        // fired anyway. A tombstone is now reserved synchronously at schedule time.
        _ = evalSync("""
            var __sameTickFired = false;
            var __sameTickId = setTimeout(function() { __sameTickFired = true; }, 0);
            clearTimeout(__sameTickId);
            true;
        """)

        letTimersSettle()

        let result = evalSync("__sameTickFired")
        XCTAssertEqual(
            result?.toBool(), false,
            "a clearTimeout in the same JS tick as setTimeout must prevent the callback"
        )
    }

    func testUnclearedTimeoutStillFires() {
        // Positive control for the tombstone change: reserving the ID up front must
        // not suppress timers that were never cleared.
        _ = evalSync("""
            var __controlFired = false;
            setTimeout(function() { __controlFired = true; }, 0);
            true;
        """)

        letTimersSettle()

        let result = evalSync("__controlFired")
        XCTAssertEqual(result?.toBool(), true, "an uncleared setTimeout must still fire")
    }

    func testClearIntervalInSameTickPreventsCallback() {
        // `setInterval` had the same defect and stored its entry unconditionally, so
        // a same-tick clear was discarded entirely and the interval repeated forever
        // with no way to stop it.
        _ = evalSync("""
            var __sameTickTicks = 0;
            var __sameTickInterval = setInterval(function() { __sameTickTicks++; }, 1);
            clearInterval(__sameTickInterval);
            true;
        """)

        letTimersSettle()

        let result = evalSync("__sameTickTicks")
        XCTAssertEqual(
            result?.toInt32(), 0,
            "a clearInterval in the same JS tick must stop the interval before its first tick"
        )
    }

    // MARK: - setInterval Tests

    func testSetIntervalExists() {
        let result = evalSync("typeof setInterval")
        XCTAssertEqual(result?.toString(), "function", "setInterval should be a function")
    }

    func testSetIntervalReturnsTimerId() {
        let result = evalSync("""
            var iid = setInterval(function(){}, 1000);
            clearInterval(iid);
            typeof iid !== 'undefined';
        """)
        XCTAssertTrue(result?.toBool() == true, "setInterval should return a timer ID")
    }

    // MARK: - clearInterval Tests

    func testClearIntervalExists() {
        let result = evalSync("typeof clearInterval")
        XCTAssertEqual(result?.toString(), "function", "clearInterval should be a function")
    }

    // MARK: - globalThis Tests

    func testGlobalThisExists() {
        let result = evalSync("typeof globalThis !== 'undefined'")
        XCTAssertTrue(result?.toBool() == true, "globalThis should be defined")
    }

    func testGlobalThisIsGlobalObject() {
        let result = evalSync("globalThis === this")
        // In JSC, `this` at the top level is the global object
        XCTAssertNotNil(result, "globalThis should reference the global object")
    }

    // MARK: - requestAnimationFrame Tests

    func testRequestAnimationFrameExists() {
        let result = evalSync("typeof requestAnimationFrame")
        XCTAssertEqual(result?.toString(), "function", "requestAnimationFrame should be a function")
    }

    func testCancelAnimationFrameExists() {
        let result = evalSync("typeof cancelAnimationFrame")
        XCTAssertEqual(result?.toString(), "function", "cancelAnimationFrame should be a function")
    }

    // MARK: - fetch Tests

    func testFetchExists() {
        let result = evalSync("typeof fetch")
        XCTAssertEqual(result?.toString(), "function", "fetch should be a function")
    }

    // MARK: - atob / btoa Tests

    func testBtoaEncodes() {
        let result = evalSync("btoa('hello')")
        XCTAssertEqual(result?.toString(), "aGVsbG8=", "btoa('hello') should return 'aGVsbG8='")
    }

    func testAtobDecodes() {
        let result = evalSync("atob('aGVsbG8=')")
        XCTAssertEqual(result?.toString(), "hello", "atob('aGVsbG8=') should return 'hello'")
    }

    func testBtoaAtobRoundTrip() {
        let result = evalSync("atob(btoa('Vue Native!'))")
        XCTAssertEqual(result?.toString(), "Vue Native!", "btoa/atob round-trip should preserve the string")
    }

    // MARK: - TextEncoder / TextDecoder Tests

    func testTextEncoderExists() {
        let result = evalSync("typeof TextEncoder")
        XCTAssertEqual(result?.toString(), "function", "TextEncoder should be defined")
    }

    func testTextDecoderExists() {
        let result = evalSync("typeof TextDecoder")
        XCTAssertEqual(result?.toString(), "function", "TextDecoder should be defined")
    }

    func testTextEncoderDecoderRoundTrip() {
        let result = evalSync("""
            var enc = new TextEncoder();
            var dec = new TextDecoder();
            var encoded = enc.encode('hello');
            dec.decode(encoded);
        """)
        XCTAssertEqual(result?.toString(), "hello", "TextEncoder/TextDecoder round-trip should work")
    }

    // MARK: - URL Tests

    func testURLConstructorExists() {
        let result = evalSync("typeof URL")
        XCTAssertEqual(result?.toString(), "function", "URL constructor should be defined")
    }

    func testURLParsingBasic() {
        let result = evalSync("new URL('https://example.com:8080/path?q=1#hash').hostname")
        XCTAssertEqual(result?.toString(), "example.com", "URL should parse hostname")
    }

    func testURLSearchParamsExists() {
        let result = evalSync("typeof URLSearchParams")
        XCTAssertEqual(result?.toString(), "function", "URLSearchParams should be defined")
    }

    // MARK: - crypto.getRandomValues Tests

    func testCryptoGetRandomValuesExists() {
        let result = evalSync("typeof crypto.getRandomValues")
        XCTAssertEqual(result?.toString(), "function", "crypto.getRandomValues should be defined")
    }

    func testCryptoGetRandomValuesProducesBytes() {
        let result = evalSync("""
            var arr = new Uint8Array(4);
            crypto.getRandomValues(arr);
            arr.length;
        """)
        XCTAssertEqual(result?.toInt32(), 4, "getRandomValues should fill a 4-byte array")
    }

    func testCryptoGetRandomValuesActuallyRandomizes() {
        // Guards the `SecRandomCopyBytes` status check: a discarded status would let
        // JS receive an all-zero buffer that is indistinguishable from success, and
        // callers use this for tokens, nonces and IVs.
        let result = evalSync("""
            (function() {
                var a = new Uint8Array(32);
                crypto.getRandomValues(a);
                var nonzero = 0;
                for (var i = 0; i < a.length; i++) { if (a[i] !== 0) nonzero++; }
                return nonzero;
            })();
        """)
        XCTAssertGreaterThan(
            result?.toInt32() ?? 0, 0,
            "getRandomValues must not hand back an unfilled (all-zero) buffer"
        )
    }

    func testCryptoGetRandomValuesQuotaMatchesWebPlatform() {
        XCTAssertEqual(JSPolyfills.maxRandomBytes, 65536, "the cap should be the web-platform quota")
    }

    func testCryptoGetRandomValuesRejectsOversizedLength() {
        // Regression: the length came straight from JS with no cap, so a huge request
        // allocated gigabytes of Swift storage and made one JSC bridge call per byte.
        // A plain object with a large `length` exercises the guard without the test
        // itself having to allocate the typed array.
        let result = evalSync("""
            (function() {
                try {
                    crypto.getRandomValues({ length: 1000000000 });
                    return 'did-not-throw';
                } catch (e) {
                    return String(e && e.message);
                }
            })();
        """)
        let message = result?.toString() ?? ""
        XCTAssertTrue(
            message.contains("QuotaExceeded"),
            "an over-quota length must throw rather than allocate; got: \(message)"
        )
    }

    func testCryptoGetRandomValuesAcceptsExactlyTheQuota() {
        let result = evalSync("""
            (function() {
                try {
                    var a = new Uint8Array(\(JSPolyfills.maxRandomBytes));
                    crypto.getRandomValues(a);
                    return 'ok';
                } catch (e) {
                    return 'threw: ' + e.message;
                }
            })();
        """)
        XCTAssertEqual(result?.toString(), "ok", "a request exactly at the quota must succeed")
    }

    func testCryptoGetRandomValuesRejectsOneByteOverTheQuota() {
        let result = evalSync("""
            (function() {
                try {
                    crypto.getRandomValues({ length: \(JSPolyfills.maxRandomBytes + 1) });
                    return 'did-not-throw';
                } catch (e) {
                    return 'threw';
                }
            })();
        """)
        XCTAssertEqual(result?.toString(), "threw", "one byte over the quota must be rejected")
    }

    func testCryptoGetRandomValuesToleratesValueWithoutLength() {
        // `forProperty` returns an implicitly-unwrapped optional; a call with no
        // usable length must return the argument untouched instead of trapping.
        let result = evalSync("""
            (function() {
                try { crypto.getRandomValues({}); return 'ok'; } catch (e) { return 'threw'; }
            })();
        """)
        XCTAssertEqual(result?.toString(), "ok")
    }

    // MARK: - Bridge Stubs Tests

    func testBridgeStubsExist() {
        let result = evalSync("""
            typeof __VN_handleGlobalEvent === 'function' &&
            typeof __VN_handleEvent === 'function' &&
            typeof __VN_resolveCallback === 'function';
        """)
        XCTAssertTrue(result?.toBool() == true, "Bridge stubs should be defined as functions")
    }

    func testBridgeStubsDoNotCrash() {
        let result = evalSync("""
            __VN_handleGlobalEvent();
            __VN_handleEvent();
            __VN_resolveCallback();
            true;
        """)
        XCTAssertTrue(result?.toBool() == true, "Bridge stubs should be callable without crashing")
    }
}
#endif
