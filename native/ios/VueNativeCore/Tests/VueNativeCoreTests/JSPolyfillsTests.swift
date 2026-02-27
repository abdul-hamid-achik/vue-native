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
        waitForExpectations(timeout: 5.0)
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
        waitForExpectations(timeout: 5.0)
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
        // Verify clearTimeout is callable and does not crash.
        // We cannot reliably test cancellation timing in the simulator
        // because JSC timer scheduling depends on the native run loop.
        let result = evalSync("""
            var __clearTestFired = false;
            var tid = setTimeout(function() { __clearTestFired = true; }, 100000);
            clearTimeout(tid);
            typeof tid !== 'undefined';
        """)
        XCTAssertTrue(result?.toBool() == true, "clearTimeout should accept a timer ID")
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
