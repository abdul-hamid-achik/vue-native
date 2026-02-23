#if canImport(UIKit)
import XCTest
import JavaScriptCore
@testable import VueNativeCore

final class JSRuntimeTests: XCTestCase {

    // MARK: - Properties

    /// We create a fresh JSContext for each test rather than using JSRuntime.shared,
    /// so tests are fully isolated and don't depend on singleton state.
    private var context: JSContext!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        context = JSContext()
        context.exceptionHandler = { _, exception in
            guard let exception = exception else { return }
            XCTFail("JS Exception: \(exception.toString() ?? "unknown")")
        }
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    // MARK: - Test: JSContext Creation

    func testJSContextCreation() {
        XCTAssertNotNil(context, "JSContext should be created successfully")

        // Test basic evaluation
        let result = context.evaluateScript("1 + 2")
        XCTAssertEqual(result?.toInt32(), 3, "JSContext should evaluate basic arithmetic")
    }

    func testJSContextStringEvaluation() {
        let result = context.evaluateScript("'Hello' + ' ' + 'Vue Native'")
        XCTAssertEqual(result?.toString(), "Hello Vue Native")
    }

    func testJSContextObjectCreation() {
        context.evaluateScript("var obj = { name: 'test', value: 42 };")
        let name = context.objectForKeyedSubscript("obj")?.objectForKeyedSubscript("name")?.toString()
        let value = context.objectForKeyedSubscript("obj")?.objectForKeyedSubscript("value")?.toInt32()
        XCTAssertEqual(name, "test")
        XCTAssertEqual(value, 42)
    }

    // MARK: - Test: Function Registration

    func testSwiftFunctionRegistration() {
        let expectation = self.expectation(description: "Swift function called from JS")

        let nativeFunction: @convention(block) (JSValue) -> Void = { value in
            XCTAssertEqual(value.toString(), "hello from JS")
            expectation.fulfill()
        }

        context.setObject(nativeFunction, forKeyedSubscript: "nativeCallback" as NSString)
        context.evaluateScript("nativeCallback('hello from JS');")

        waitForExpectations(timeout: 1.0)
    }

    func testObjectForKeyedSubscriptCall() {
        // Test that objectForKeyedSubscript().call() works correctly
        // This is the pattern used by JSRuntime.callFunction() for performance
        context.evaluateScript("""
            function add(a, b) { return a + b; }
        """)

        let addFn = context.objectForKeyedSubscript("add")
        XCTAssertNotNil(addFn)
        XCTAssertFalse(addFn!.isUndefined)

        let result = addFn?.call(withArguments: [3, 4])
        XCTAssertEqual(result?.toInt32(), 7)
    }

    // MARK: - Test: Console Polyfills

    func testConsolePolyfills() {
        // Register console polyfills
        registerConsolePolyfills()

        // These should not crash
        context.evaluateScript("console.log('test log');")
        context.evaluateScript("console.warn('test warn');")
        context.evaluateScript("console.error('test error');")

        // Verify console object exists
        let consoleObj = context.objectForKeyedSubscript("console")
        XCTAssertNotNil(consoleObj)
        XCTAssertFalse(consoleObj!.isUndefined)
    }

    // MARK: - Test: setTimeout Polyfill

    func testSetTimeoutPolyfill() {
        let expectation = self.expectation(description: "setTimeout fires")

        // Simple setTimeout implementation for testing
        let setTimeout: @convention(block) (JSValue, JSValue) -> JSValue = { callback, delay in
            let delayMs = delay.toDouble()
            DispatchQueue.main.asyncAfter(deadline: .now() + delayMs / 1000.0) {
                callback.call(withArguments: [])
            }
            return JSValue(int32: 1, in: JSContext.current())
        }

        context.setObject(setTimeout, forKeyedSubscript: "setTimeout" as NSString)

        let fulfilled: @convention(block) () -> Void = {
            expectation.fulfill()
        }
        context.setObject(fulfilled, forKeyedSubscript: "testFulfill" as NSString)

        context.evaluateScript("setTimeout(testFulfill, 50);")

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - Test: queueMicrotask Polyfill

    func testQueueMicrotaskPolyfill() {
        // queueMicrotask uses Promise.resolve().then()
        context.evaluateScript("""
            function queueMicrotask(callback) {
                Promise.resolve().then(callback);
            }
        """)

        // Verify the function exists
        let fn = context.objectForKeyedSubscript("queueMicrotask")
        XCTAssertNotNil(fn)
        XCTAssertFalse(fn!.isUndefined)
    }

    // MARK: - Test: Microtask Drain (CRITICAL for Vue's scheduler)

    func testMicrotaskDrain() {
        // This is the CRITICAL test that validates Vue's scheduler will work.
        // Vue uses Promise.resolve().then() for async batching.
        // After evaluateScript returns, microtasks should have drained.

        context.evaluateScript("""
            var result = [];
            Promise.resolve().then(function() { result.push('micro1'); });
            result.push('sync');
            Promise.resolve().then(function() { result.push('micro2'); });
        """)

        // Force microtask drain
        context.evaluateScript("void 0;")

        let result = context.objectForKeyedSubscript("result")?.toArray() as? [String]

        // After evaluation + drain, the result should include both sync and microtask items
        // The exact order depends on when JSC drains the microtask queue.
        // Expected: ["sync", "micro1", "micro2"]
        XCTAssertNotNil(result, "result array should exist")

        if let result = result {
            XCTAssertTrue(result.contains("sync"), "Synchronous code should have run")
            // Microtasks should drain after evaluateScript
            XCTAssertTrue(result.contains("micro1"), "First microtask should have drained")
            XCTAssertTrue(result.contains("micro2"), "Second microtask should have drained")

            // sync should be first
            if let syncIdx = result.firstIndex(of: "sync"),
               let micro1Idx = result.firstIndex(of: "micro1") {
                XCTAssertLessThan(syncIdx, micro1Idx, "sync should run before microtasks")
            }
        }
    }

    func testMicrotaskChaining() {
        // Test that chained microtasks also drain
        context.evaluateScript("""
            var order = [];
            Promise.resolve()
                .then(function() {
                    order.push('first');
                    return Promise.resolve();
                })
                .then(function() {
                    order.push('second');
                });
            order.push('sync');
        """)

        // Force drain
        context.evaluateScript("void 0;")

        let order = context.objectForKeyedSubscript("order")?.toArray() as? [String]
        XCTAssertNotNil(order)

        if let order = order {
            XCTAssertEqual(order.first, "sync", "Sync should run first")
            XCTAssertTrue(order.contains("first"), "First chained microtask should drain")
            XCTAssertTrue(order.contains("second"), "Second chained microtask should drain")
        }
    }

    func testAsyncAwaitMicrotasks() {
        // Test async/await (which compiles to Promise chains in JSC)
        context.evaluateScript("""
            var asyncResult = [];
            async function runAsync() {
                asyncResult.push('before await');
                await Promise.resolve();
                asyncResult.push('after await');
            }
            runAsync();
            asyncResult.push('after call');
        """)

        // Force drain
        context.evaluateScript("void 0;")

        let asyncResult = context.objectForKeyedSubscript("asyncResult")?.toArray() as? [String]
        XCTAssertNotNil(asyncResult)

        if let asyncResult = asyncResult {
            XCTAssertTrue(asyncResult.contains("before await"))
            XCTAssertTrue(asyncResult.contains("after call"))
            // "after await" should drain as a microtask
            XCTAssertTrue(asyncResult.contains("after await"), "Post-await code should drain as microtask")
        }
    }

    // MARK: - Test: Performance.now Polyfill

    func testPerformanceNowPolyfill() {
        // Register a simple performance.now
        let startTime = CFAbsoluteTimeGetCurrent()
        let performanceNow: @convention(block) () -> Double = {
            return (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        }
        context.evaluateScript("var performance = {};")
        let perfObj = context.objectForKeyedSubscript("performance")!
        perfObj.setObject(performanceNow, forKeyedSubscript: "now" as NSString)

        let result = context.evaluateScript("performance.now()")
        XCTAssertNotNil(result)

        let time = result?.toDouble() ?? -1
        XCTAssertGreaterThanOrEqual(time, 0, "performance.now() should return non-negative value")
        XCTAssertLessThan(time, 1000, "performance.now() should return a reasonable value (< 1s)")
    }

    // MARK: - Test: globalThis

    func testGlobalThis() {
        context.evaluateScript("var globalThis = this;")

        let result = context.evaluateScript("globalThis === this")
        XCTAssertTrue(result?.toBool() ?? false, "globalThis should equal the global object")
    }

    // MARK: - Test: JSRuntime Singleton (Integration)

    func testJSRuntimeInitialize() {
        let expectation = self.expectation(description: "JSRuntime initializes")

        let runtime = JSRuntime.shared

        runtime.initialize {
            XCTAssertTrue(runtime.isInitialized, "Runtime should be initialized")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    func testJSRuntimeEvaluateScript() {
        let expectation = self.expectation(description: "evaluateScript completes")

        let runtime = JSRuntime.shared

        runtime.initialize {
            runtime.evaluateScript("1 + 1") { result in
                XCTAssertEqual(result?.toInt32(), 2)
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    func testJSRuntimeCallFunction() {
        let expectation = self.expectation(description: "callFunction completes")

        let runtime = JSRuntime.shared

        runtime.initialize {
            runtime.evaluateScript("function multiply(a, b) { return a * b; }") { _ in
                runtime.callFunction("multiply", withArguments: [6, 7]) { result in
                    XCTAssertEqual(result?.toInt32(), 42)
                    expectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    // MARK: - Test: JSON Operation Parsing

    func testOperationJSONParsing() {
        // Test that our expected operation format can be parsed
        let json = """
        [
            {"op": "create", "args": [1, "VView"]},
            {"op": "createText", "args": [2, "Hello"]},
            {"op": "appendChild", "args": [1, 2]},
            {"op": "updateStyle", "args": [1, {"backgroundColor": "#ff0000", "padding": 16}]},
            {"op": "setRootView", "args": [1]}
        ]
        """

        let data = json.data(using: .utf8)!
        let operations = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        XCTAssertNotNil(operations)
        XCTAssertEqual(operations?.count, 5)

        // Verify first operation
        XCTAssertEqual(operations?[0]["op"] as? String, "create")
        if let args = operations?[0]["args"] as? [Any] {
            XCTAssertEqual(args[0] as? Int, 1)
            XCTAssertEqual(args[1] as? String, "VView")
        }

        // Verify style operation has nested dictionary
        if let args = operations?[3]["args"] as? [Any],
           let styles = args[1] as? [String: Any] {
            XCTAssertEqual(styles["backgroundColor"] as? String, "#ff0000")
            XCTAssertEqual(styles["padding"] as? Int, 16)
        }
    }

    // MARK: - Helpers

    private func registerConsolePolyfills() {
        context.evaluateScript("var console = {};")

        let log: @convention(block) (JSValue) -> Void = { _ in }
        let warn: @convention(block) (JSValue) -> Void = { _ in }
        let error: @convention(block) (JSValue) -> Void = { _ in }

        let consoleObj = context.objectForKeyedSubscript("console")!
        consoleObj.setObject(log, forKeyedSubscript: "log" as NSString)
        consoleObj.setObject(warn, forKeyedSubscript: "warn" as NSString)
        consoleObj.setObject(error, forKeyedSubscript: "error" as NSString)
    }
}
#endif
