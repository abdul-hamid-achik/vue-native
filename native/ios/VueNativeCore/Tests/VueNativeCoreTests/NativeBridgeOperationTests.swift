#if canImport(UIKit)
import XCTest
import UIKit
import JavaScriptCore
@testable import VueNativeCore

@MainActor
final class NativeBridgeOperationTests: XCTestCase {

    // MARK: - Properties

    private var bridge: NativeBridge!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        bridge = NativeBridge.shared
        // NativeBridge is main-actor isolated, so reset completes synchronously.
        bridge.reset()
    }

    override func tearDown() {
        bridge.reset()
        bridge = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Process a single operation for convenience.
    private func processOp(_ op: String, args: [Any]) {
        bridge.processOperations([["op": op, "args": args]])
    }

    /// Process multiple operations in a single batch.
    private func processBatch(_ operations: [[String: Any]]) {
        bridge.processOperations(operations)
    }

    private func installNativeCallbackResolver(
        _ handler: @escaping (Int, String?) -> Void
    ) async {
        let runtime = JSRuntime.shared
        let initialized = expectation(description: "JavaScript runtime initialized")
        runtime.initialize {
            initialized.fulfill()
        }
        await fulfillment(of: [initialized], timeout: 2)

        runtime.jsQueue.sync {
            guard let context = runtime.context else {
                return XCTFail("Expected an initialized JavaScript context")
            }
            let resolver: @convention(block) (JSValue, JSValue, JSValue) -> Void = { callbackIDValue, resultValue, _ in
                let callbackID = Int(callbackIDValue.toInt32())
                let result = resultValue.isNull || resultValue.isUndefined
                    ? nil
                    : resultValue.toString()
                Task { @MainActor in
                    handler(callbackID, result)
                }
            }
            context.setObject(
                resolver,
                forKeyedSubscript: "__VN_resolveCallback" as NSString
            )
        }
    }

    private func uninstallNativeCallbackResolver() {
        let runtime = JSRuntime.shared
        runtime.jsQueue.sync {
            guard let context = runtime.context else { return }
            let resolver: @convention(block) (JSValue, JSValue, JSValue) -> Void = { _, _, _ in }
            context.setObject(
                resolver,
                forKeyedSubscript: "__VN_resolveCallback" as NSString
            )
        }
    }

    // MARK: - Public Host Integration

    func testHostIntegrationSeedsInitialURL() {
        let url = URL(string: "vuenative://profile/42")!
        bridge.setInitialURL(url)

        var result: Any?
        LinkingModule().invoke(method: "getInitialURL", args: []) { value, error in
            XCTAssertNil(error)
            result = value
        }

        XCTAssertEqual(result as? String, url.absoluteString)
        bridge.setInitialURL(nil)
    }

    func testHostIntegrationCachesAPNsTokenForGetToken() {
        bridge.didRegisterForRemoteNotifications(deviceToken: Data([0x01, 0xab, 0xff]))

        XCTAssertEqual(NotificationsModule.cachedDeviceToken, "01abff")
    }

    // MARK: - create Tests

    func testCreateRegistersView() {
        let initialCount = bridge.registeredViewCount
        processOp("create", args: [1, "VView"])

        let view = bridge.view(forNodeId: 1)
        XCTAssertNotNil(view, "create should register a view for the given node ID")
        XCTAssertEqual(
            bridge.registeredViewCount,
            initialCount + 1,
            "registeredViewCount should increase by 1"
        )
    }

    func testCreateWithDifferentComponentTypes() {
        processOp("create", args: [10, "VText"])
        let textView = bridge.view(forNodeId: 10)
        XCTAssertNotNil(textView, "create should work with VText")
        XCTAssertTrue(textView is UILabel, "VText should create a UILabel")

        processOp("create", args: [11, "VSwitch"])
        let switchView = bridge.view(forNodeId: 11)
        XCTAssertNotNil(switchView, "create should work with VSwitch")
        XCTAssertTrue(switchView is UISwitch, "VSwitch should create a UISwitch")
    }

    // MARK: - createText Tests

    func testCreateTextCreatesLabelWithText() {
        processOp("createText", args: [2, "Hello"])

        let view = bridge.view(forNodeId: 2)
        XCTAssertNotNil(view, "createText should register a view")
        XCTAssertTrue(view is UILabel, "createText should create a UILabel")

        if let label = view as? UILabel {
            XCTAssertEqual(label.text, "Hello", "UILabel text should be 'Hello'")
        }
    }

    func testCreateTextWithEmptyString() {
        processOp("createText", args: [3, ""])

        let view = bridge.view(forNodeId: 3)
        XCTAssertNotNil(view, "createText should work with empty string")
        if let label = view as? UILabel {
            XCTAssertEqual(label.text, "", "UILabel text should be empty string")
        }
    }

    // MARK: - appendChild Tests

    func testAppendChildAddsSubview() {
        processOp("create", args: [1, "VView"])
        processOp("create", args: [2, "VView"])
        processOp("appendChild", args: [1, 2])

        let parent = bridge.view(forNodeId: 1)!
        let child = bridge.view(forNodeId: 2)!

        XCTAssertTrue(
            child.isDescendant(of: parent),
            "Child should be a descendant of parent after appendChild"
        )
    }

    func testAppendChildMultipleChildren() {
        processOp("create", args: [1, "VView"])
        processOp("create", args: [2, "VView"])
        processOp("create", args: [3, "VView"])
        processOp("appendChild", args: [1, 2])
        processOp("appendChild", args: [1, 3])

        let parent = bridge.view(forNodeId: 1)!
        let child1 = bridge.view(forNodeId: 2)!
        let child2 = bridge.view(forNodeId: 3)!

        XCTAssertTrue(child1.isDescendant(of: parent), "First child should be in parent")
        XCTAssertTrue(child2.isDescendant(of: parent), "Second child should be in parent")
    }

    func testInsertBeforeMovesExistingChildWithoutDuplicatingIt() {
        processOp("create", args: [1, "VView"])
        processOp("create", args: [2, "VView"])
        processOp("create", args: [3, "VView"])
        processOp("appendChild", args: [1, 2])
        processOp("appendChild", args: [1, 3])

        processOp("insertBefore", args: [1, 3, 2])

        let parent = bridge.view(forNodeId: 1)!
        let first = bridge.view(forNodeId: 2)!
        let second = bridge.view(forNodeId: 3)!
        XCTAssertEqual(parent.subviews.first, second, "Moved child should be before its anchor")
        XCTAssertEqual(parent.subviews.dropFirst().first, first)
        XCTAssertEqual(parent.subviews.filter { $0 === second }.count, 1, "A keyed move must not duplicate the view")
    }

    func testReparentedChildSurvivesRemovingItsOldParent() {
        processOp("create", args: [1, "VView"])
        processOp("create", args: [2, "VView"])
        processOp("create", args: [3, "VView"])
        processOp("appendChild", args: [1, 3])

        processOp("appendChild", args: [2, 3])

        let newParent = bridge.view(forNodeId: 2)!
        let child = bridge.view(forNodeId: 3)!
        XCTAssertTrue(child.isDescendant(of: newParent))

        processOp("removeChild", args: [1])

        XCTAssertNotNil(bridge.view(forNodeId: 3), "Removing the old parent must not unregister a moved child")
        XCTAssertTrue(child.isDescendant(of: newParent))
    }

    func testInitializeWithNewHostClearsOldRootBeforeReplacingController() {
        let firstController = UIViewController()
        firstController.loadViewIfNeeded()
        bridge.prepareHost(rootViewController: firstController)

        processOp("create", args: [1, "__ROOT__"])
        processOp("setRootView", args: [1])
        let oldRoot = bridge.view(forNodeId: 1)
        XCTAssertTrue(oldRoot?.superview === firstController.view)

        let secondController = UIViewController()
        secondController.loadViewIfNeeded()
        bridge.prepareHost(rootViewController: secondController)

        XCTAssertEqual(bridge.registeredViewCount, 0)
        XCTAssertNil(oldRoot?.superview)
        XCTAssertTrue(firstController.view.subviews.isEmpty)

        processOp("create", args: [2, "__ROOT__"])
        processOp("setRootView", args: [2])
        XCTAssertTrue(bridge.view(forNodeId: 2)?.superview === secondController.view)
    }

    // MARK: - removeChild Tests

    func testRemoveChildRemovesFromParent() {
        processOp("create", args: [1, "VView"])
        processOp("create", args: [2, "VView"])
        processOp("appendChild", args: [1, 2])

        let parent = bridge.view(forNodeId: 1)!
        let child = bridge.view(forNodeId: 2)!

        XCTAssertTrue(child.isDescendant(of: parent), "Child should be in parent before removal")

        let countBefore = bridge.registeredViewCount
        processOp("removeChild", args: [2])

        XCTAssertFalse(child.isDescendant(of: parent), "Child should be removed from parent")
        XCTAssertNil(bridge.view(forNodeId: 2), "Removed child should no longer be in registry")
        XCTAssertEqual(
            bridge.registeredViewCount,
            countBefore - 1,
            "registeredViewCount should decrease by 1"
        )
    }

    // MARK: - updateProp Tests

    func testUpdatePropAppliesStyle() {
        processOp("create", args: [1, "VView"])
        processOp("updateProp", args: [1, "backgroundColor", "#ff0000"])

        let view = bridge.view(forNodeId: 1)!
        XCTAssertNotNil(view.backgroundColor, "backgroundColor should be set via updateProp")

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        view.backgroundColor!.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01, "Red should be 1.0")
    }

    // MARK: - updateStyle Tests

    func testUpdateStyleAppliesStyles() {
        processOp("create", args: [1, "VView"])
        processOp("updateStyle", args: [1, ["opacity": 0.5]])

        let view = bridge.view(forNodeId: 1)!
        XCTAssertEqual(view.alpha, 0.5, accuracy: 0.001, "alpha should be 0.5 after updateStyle")
    }

    func testUpdateStyleMultipleProperties() {
        processOp("create", args: [1, "VView"])
        processOp("updateStyle", args: [1, [
            "opacity": 0.7,
            "borderRadius": 12.0,
        ]])

        let view = bridge.view(forNodeId: 1)!
        XCTAssertEqual(view.alpha, 0.7, accuracy: 0.001, "alpha should be 0.7")
        XCTAssertEqual(view.layer.cornerRadius, 12.0, accuracy: 0.001, "cornerRadius should be 12")
    }

    // MARK: - setText Tests

    func testSetTextUpdatesLabel() {
        processOp("createText", args: [2, "Hello"])
        processOp("setText", args: [2, "World"])

        let label = bridge.view(forNodeId: 2) as? UILabel
        XCTAssertNotNil(label, "View should be a UILabel")
        XCTAssertEqual(label?.text, "World", "setText should update the label text to 'World'")
    }

    // MARK: - addEventListener Tests

    func testAddEventListenerRegistersHandler() {
        processOp("create", args: [1, "VView"])
        processOp("addEventListener", args: [1, "press"])

        // After addEventListener, the view should have a gesture recognizer
        let view = bridge.view(forNodeId: 1)!
        let hasTapRecognizer = view.gestureRecognizers?.contains(where: { $0 is UITapGestureRecognizer }) ?? false
        XCTAssertTrue(hasTapRecognizer, "View should have a tap gesture recognizer after addEventListener for 'press'")
        XCTAssertTrue(view.isUserInteractionEnabled, "User interaction should be enabled")
    }

    // MARK: - insertBefore Tests

    func testInsertBeforeOrdersCorrectly() {
        processOp("create", args: [1, "VView"])
        processOp("create", args: [2, "VView"])
        processOp("create", args: [3, "VView"])

        // Append child2 first
        processOp("appendChild", args: [1, 2])
        // Insert child3 before child2
        processOp("insertBefore", args: [1, 3, 2])

        let parent = bridge.view(forNodeId: 1)!
        let child2 = bridge.view(forNodeId: 2)!
        let child3 = bridge.view(forNodeId: 3)!

        XCTAssertTrue(child2.isDescendant(of: parent), "child2 should be in parent")
        XCTAssertTrue(child3.isDescendant(of: parent), "child3 should be in parent")

        // child3 should come before child2 in the subview order
        if let idx2 = parent.subviews.firstIndex(of: child2),
           let idx3 = parent.subviews.firstIndex(of: child3) {
            XCTAssertLessThan(idx3, idx2, "child3 should be before child2 in subview order")
        } else {
            XCTFail("Both children should be found in parent's subviews")
        }
    }

    // MARK: - Batch Operations Tests

    func testMultipleOperationsInBatch() {
        let operations: [[String: Any]] = [
            ["op": "create", "args": [1, "VView"]],
            ["op": "create", "args": [2, "VView"]],
            ["op": "appendChild", "args": [1, 2]],
            ["op": "updateStyle", "args": [2, ["opacity": 0.8]]],
        ]

        processBatch(operations)

        let parent = bridge.view(forNodeId: 1)
        let child = bridge.view(forNodeId: 2)

        XCTAssertNotNil(parent, "Parent should be created")
        XCTAssertNotNil(child, "Child should be created")
        XCTAssertTrue(child!.isDescendant(of: parent!), "Child should be in parent")
        XCTAssertEqual(child!.alpha, 0.8, accuracy: 0.001, "Child opacity should be 0.8")
    }

    // MARK: - Unknown Operation Tests

    func testUnknownOperationDoesNotCrash() {
        let operations: [[String: Any]] = [
            ["op": "unknownOperation", "args": [1, 2, 3]],
        ]
        // Should not crash
        processBatch(operations)
    }

    // MARK: - Invalid Args Tests

    func testInvalidArgsDoesNotCrash() {
        // Missing args key
        let operations1: [[String: Any]] = [
            ["op": "create"],
        ]
        processBatch(operations1)

        // Args with wrong types
        let operations2: [[String: Any]] = [
            ["op": "create", "args": ["notAnInt", 123]],
        ]
        processBatch(operations2)

        // Empty args
        let operations3: [[String: Any]] = [
            ["op": "create", "args": []],
        ]
        processBatch(operations3)
    }

    // MARK: - Reset Tests

    func testHostReplacementIgnoresStaleNativeCallbackWhenIDIsReused() async {
        let resolved = expectation(description: "Only the current callback resolves")
        var resolvedCallbackIDs: [Int] = []
        var resolvedValues: [String?] = []
        await installNativeCallbackResolver { callbackID, result in
            resolvedCallbackIDs.append(callbackID)
            resolvedValues.append(result)
            resolved.fulfill()
        }
        defer { uninstallNativeCallbackResolver() }

        let firstController = UIViewController()
        firstController.loadViewIfNeeded()
        bridge.prepareHost(rootViewController: firstController)

        let module = DelayedCallbackModule()
        NativeModuleRegistry.shared.register(module)
        processOp(
            "invokeNativeModule",
            args: [module.moduleName, "wait", [], 42]
        )
        XCTAssertEqual(module.pendingCallbackCount, 1)

        let replacementController = UIViewController()
        replacementController.loadViewIfNeeded()
        bridge.prepareHost(rootViewController: replacementController)

        processOp(
            "invokeNativeModule",
            args: [module.moduleName, "wait", [], 42]
        )
        XCTAssertEqual(module.pendingCallbackCount, 2)

        module.completeNext(with: "stale")
        module.completeNext(with: "current")

        await fulfillment(of: [resolved], timeout: 2)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(resolvedCallbackIDs, [42])
        XCTAssertEqual(resolvedValues, ["current"])
    }

    func testResetClearsAllState() {
        processOp("create", args: [100, "VView"])
        processOp("create", args: [101, "VText"])
        processOp("createText", args: [102, "Test"])

        XCTAssertGreaterThanOrEqual(
            bridge.registeredViewCount, 3,
            "Should have at least 3 registered views before reset"
        )

        bridge.reset()
        // Drain the main run loop to let the async reset block execute
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertEqual(bridge.registeredViewCount, 0, "registeredViewCount should be 0 after reset")
        XCTAssertNil(bridge.view(forNodeId: 100), "View 100 should be nil after reset")
        XCTAssertNil(bridge.view(forNodeId: 101), "View 101 should be nil after reset")
        XCTAssertNil(bridge.view(forNodeId: 102), "View 102 should be nil after reset")
    }

    // MARK: - removeEventListener Tests

    func testRemoveEventListenerRemovesHandler() {
        processOp("create", args: [1, "VView"])
        processOp("addEventListener", args: [1, "press"])

        let view = bridge.view(forNodeId: 1)!
        let tapCountBefore = view.gestureRecognizers?.filter { $0 is UITapGestureRecognizer }.count ?? 0
        XCTAssertGreaterThan(tapCountBefore, 0, "Should have tap recognizer before removal")

        processOp("removeEventListener", args: [1, "press"])

        let tapCountAfter = view.gestureRecognizers?.filter { $0 is UITapGestureRecognizer }.count ?? 0
        XCTAssertEqual(tapCountAfter, 0, "Tap recognizer should be removed after removeEventListener")
    }

    // MARK: - Node ID Types

    func testCreateWithDoubleNodeId() {
        // JSON numbers from JSONSerialization may come as Double
        processOp("create", args: [5.0, "VView"])
        let view = bridge.view(forNodeId: 5)
        XCTAssertNotNil(view, "create should handle Double node IDs (JSON deserialization)")
    }

    // MARK: - create Unknown Component Type

    func testCreateUnknownComponentType() {
        // Creating a view with an unknown type should not crash
        processOp("create", args: [999, "UnknownWidget"])
        let view = bridge.view(forNodeId: 999)
        XCTAssertNil(view, "Unknown component type should not create a view")
    }

    // MARK: - removeChild Cleans Up Descendants

    func testRemoveChildCleansUpDescendants() {
        // Build a tree: root(1) -> parent(2) -> child(3)
        processOp("create", args: [1, "VView"])
        processOp("create", args: [2, "VView"])
        processOp("create", args: [3, "VView"])
        processOp("appendChild", args: [1, 2])
        processOp("appendChild", args: [2, 3])

        // Verify both exist
        XCTAssertNotNil(bridge.view(forNodeId: 2), "Parent should exist")
        XCTAssertNotNil(bridge.view(forNodeId: 3), "Child should exist")

        // Remove parent (2), which should also clean up child (3)
        processOp("removeChild", args: [2])

        XCTAssertNil(bridge.view(forNodeId: 2), "Removed parent should be cleaned up")
        XCTAssertNil(bridge.view(forNodeId: 3), "Descendant should be cleaned up recursively")
    }

    func testRemoveChildDestroysEachViewInSubtreeExactlyOnce() {
        let factory = DestroyProbeFactory()
        ComponentRegistry.shared.register("DestroyProbe", factory: factory)
        defer { ComponentRegistry.shared.unregister("DestroyProbe") }

        processOp("create", args: [201, "DestroyProbe"])
        processOp("create", args: [202, "DestroyProbe"])
        processOp("appendChild", args: [201, 202])

        processOp("removeChild", args: [201])
        processOp("removeChild", args: [201])

        let createdIDs = Set(factory.createdViews.map { ObjectIdentifier($0) })
        XCTAssertEqual(factory.destroyedViewIDs.count, 2)
        XCTAssertEqual(Set(factory.destroyedViewIDs), createdIDs)
    }

    func testMoveDoesNotDestroyViewAndResetDestroysItOnce() {
        let factory = DestroyProbeFactory()
        ComponentRegistry.shared.register("DestroyProbe", factory: factory)
        defer { ComponentRegistry.shared.unregister("DestroyProbe") }

        processOp("create", args: [211, "VView"])
        processOp("create", args: [212, "VView"])
        processOp("create", args: [213, "DestroyProbe"])
        processOp("appendChild", args: [211, 213])

        processOp("appendChild", args: [212, 213])

        XCTAssertTrue(factory.destroyedViewIDs.isEmpty, "Reparenting must not destroy a live node")

        bridge.reset()
        bridge.reset()

        XCTAssertEqual(factory.destroyedViewIDs.count, 1, "Reset must destroy each registered view once")
        XCTAssertEqual(factory.destroyedViewIDs.first, factory.createdViews.first.map { ObjectIdentifier($0) })
    }

    // MARK: - setElementText Tests

    func testSetElementTextUpdatesLabel() {
        processOp("createText", args: [5, "Original"])
        processOp("setElementText", args: [5, "Updated"])

        let label = bridge.view(forNodeId: 5) as? UILabel
        XCTAssertEqual(label?.text, "Updated", "setElementText should update the label text")
    }

    // MARK: - Operations on Non-Existent Nodes

    func testOperationsOnNonExistentNodesDoNotCrash() {
        // All of these should silently fail without crashing
        processOp("appendChild", args: [999, 998])
        processOp("removeChild", args: [999])
        processOp("updateProp", args: [999, "backgroundColor", "#ff0000"])
        processOp("updateStyle", args: [999, ["opacity": 0.5]])
        processOp("setText", args: [999, "test"])
        processOp("addEventListener", args: [999, "press"])
        processOp("insertBefore", args: [999, 998, 997])
    }

    // MARK: - Empty Batch

    func testEmptyBatchDoesNotCrash() {
        processBatch([])
    }
}

@MainActor
private final class DestroyProbeFactory: NativeComponentFactory {
    private(set) var createdViews: [UIView] = []
    private(set) var destroyedViewIDs: [ObjectIdentifier] = []

    func createView() -> UIView {
        let view = UIView()
        createdViews.append(view)
        return view
    }

    func updateProp(view: UIView, key: String, value: Any?) {}

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {}

    func destroyView(view: UIView) {
        destroyedViewIDs.append(ObjectIdentifier(view))
    }
}

private final class DelayedCallbackModule: NativeModule {
    let moduleName = "DelayedCallbackProbe"
    private var callbacks: [(Any?, String?) -> Void] = []

    var pendingCallbackCount: Int { callbacks.count }

    func invoke(
        method: String,
        args: [Any],
        callback: @escaping (Any?, String?) -> Void
    ) {
        callbacks.append(callback)
    }

    func completeNext(with result: Any?) {
        guard !callbacks.isEmpty else { return }
        callbacks.removeFirst()(result, nil)
    }
}
#endif
