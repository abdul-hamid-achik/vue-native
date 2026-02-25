#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

@MainActor
final class NativeModuleRegistryTests: XCTestCase {

    // MARK: - Properties

    private var moduleRegistry: NativeModuleRegistry!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        moduleRegistry = NativeModuleRegistry.shared
    }

    override func tearDown() {
        moduleRegistry = nil
        super.tearDown()
    }

    // MARK: - Register and Invoke

    func testRegisterAndInvokeModule() {
        let mock = MockNativeModule(name: "TestModule")
        mock.resultToReturn = ["status": "ok"]
        moduleRegistry.register(mock)

        let expectation = self.expectation(description: "invoke callback called")

        moduleRegistry.invoke(module: "TestModule", method: "doSomething", args: ["arg1", 42]) { result, error in
            XCTAssertNil(error, "Error should be nil for successful invocation")
            XCTAssertNotNil(result, "Result should not be nil")
            if let dict = result as? [String: String] {
                XCTAssertEqual(dict["status"], "ok", "Result should match the configured return value")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.lastMethod, "doSomething", "Method name should be recorded")
        XCTAssertEqual(mock.lastArgs?.count, 2, "Args should be passed through")
        XCTAssertEqual(mock.lastArgs?[0] as? String, "arg1", "First arg should be 'arg1'")
        XCTAssertEqual(mock.lastArgs?[1] as? Int, 42, "Second arg should be 42")
    }

    // MARK: - Invoke Unknown Module

    func testInvokeUnknownModuleCallsCallbackWithError() {
        let expectation = self.expectation(description: "invoke callback called with error")

        moduleRegistry.invoke(module: "UnknownModule", method: "test", args: []) { result, error in
            XCTAssertNil(result, "Result should be nil for unknown module")
            XCTAssertNotNil(error, "Error should not be nil for unknown module")
            XCTAssertTrue(
                error!.contains("not found"),
                "Error message should indicate module not found, got: \(error!)"
            )
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    // MARK: - InvokeSync Unknown Module

    func testInvokeSyncUnknownModuleReturnsNil() {
        let result = moduleRegistry.invokeSync(module: "UnknownSyncModule", method: "test", args: [])
        XCTAssertNil(result, "invokeSync should return nil for unknown module")
    }

    // MARK: - InvokeSync with Mock

    func testInvokeSyncCallsThroughToModule() {
        let mock = MockNativeModule(name: "SyncTestModule")
        mock.resultToReturn = 99
        moduleRegistry.register(mock)

        let result = moduleRegistry.invokeSync(module: "SyncTestModule", method: "getCount", args: ["param"])

        XCTAssertEqual(result as? Int, 99, "invokeSync should return the module's result")
        XCTAssertEqual(mock.lastMethod, "getCount", "Method name should be recorded")
        XCTAssertEqual(mock.lastArgs?.count, 1, "Args should be passed through")
        XCTAssertEqual(mock.lastArgs?[0] as? String, "param", "First arg should be 'param'")
    }

    // MARK: - Register Overwrites Existing Module

    func testRegisterOverwritesModuleWithSameName() {
        let mock1 = MockNativeModule(name: "OverwriteModule")
        mock1.resultToReturn = "first"
        moduleRegistry.register(mock1)

        let mock2 = MockNativeModule(name: "OverwriteModule")
        mock2.resultToReturn = "second"
        moduleRegistry.register(mock2)

        let result = moduleRegistry.invokeSync(module: "OverwriteModule", method: "test", args: [])
        XCTAssertEqual(result as? String, "second", "The second registered module should take precedence")
        XCTAssertTrue(mock2.lastMethod == "test", "Second mock should have been invoked")
        XCTAssertNil(mock1.lastMethod, "First mock should NOT have been invoked")
    }

    // MARK: - Individual Known Modules Can Be Registered

    func testKnownModulesCanBeRegisteredIndividually() {
        // registerDefaults() triggers all modules including ones that need a real
        // app context (e.g. NotificationsModule accesses Bundle.main which crashes
        // in the xctest host). Instead, register a few safe modules individually
        // and verify they are invokable.
        moduleRegistry.register(HapticsModule())
        moduleRegistry.register(AsyncStorageModule())
        moduleRegistry.register(ClipboardModule())
        moduleRegistry.register(DeviceInfoModule())

        let knownModules = ["Haptics", "AsyncStorage", "Clipboard", "DeviceInfo"]

        for moduleName in knownModules {
            let expectation = self.expectation(description: "\(moduleName) registered")

            moduleRegistry.invoke(module: moduleName, method: "__nonexistent__", args: []) { _, error in
                // The module should be found (no "not found" error).
                // It may return a method-level error, but NOT a module-not-found error.
                if let error = error {
                    XCTAssertFalse(
                        error.contains("not found"),
                        "Module '\(moduleName)' should be registered, but got error: \(error)"
                    )
                }
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - Multiple Args Passed Correctly

    func testMultipleArgsPassed() {
        let mock = MockNativeModule(name: "ArgsTestModule")
        mock.resultToReturn = nil
        moduleRegistry.register(mock)

        let expectation = self.expectation(description: "invoke callback called")

        let args: [Any] = ["hello", 42, true, 3.14]
        moduleRegistry.invoke(module: "ArgsTestModule", method: "multiArgs", args: args) { _, _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.lastArgs?.count, 4, "All 4 args should be passed")
        XCTAssertEqual(mock.lastArgs?[0] as? String, "hello", "First arg should be 'hello'")
        XCTAssertEqual(mock.lastArgs?[1] as? Int, 42, "Second arg should be 42")
        XCTAssertEqual(mock.lastArgs?[2] as? Bool, true, "Third arg should be true")
        XCTAssertEqual(mock.lastArgs?[3] as? Double, 3.14, "Fourth arg should be 3.14")
    }

    // MARK: - Empty Args

    func testEmptyArgs() {
        let mock = MockNativeModule(name: "EmptyArgsModule")
        mock.resultToReturn = "done"
        moduleRegistry.register(mock)

        let result = moduleRegistry.invokeSync(module: "EmptyArgsModule", method: "noArgs", args: [])
        XCTAssertEqual(result as? String, "done", "invokeSync should work with empty args")
        XCTAssertEqual(mock.lastArgs?.count, 0, "Args array should be empty")
    }
}

// MARK: - MockNativeModule

/// A test-only NativeModule that records invocations for verification.
private final class MockNativeModule: NativeModule {

    var moduleName: String
    var lastMethod: String?
    var lastArgs: [Any]?
    var resultToReturn: Any?

    init(name: String) {
        self.moduleName = name
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        lastMethod = method
        lastArgs = args
        callback(resultToReturn, nil)
    }

    func invokeSync(method: String, args: [Any]) -> Any? {
        lastMethod = method
        lastArgs = args
        return resultToReturn
    }
}
#endif
