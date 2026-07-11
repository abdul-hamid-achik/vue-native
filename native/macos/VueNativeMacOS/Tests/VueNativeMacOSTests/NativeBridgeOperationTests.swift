import AppKit
import XCTest
import JavaScriptCore
import VueNativeShared
@testable import VueNativeMacOS

@MainActor
final class NativeBridgeOperationTests: XCTestCase {

    private var bridge: NativeBridge!

    override func setUp() {
        super.setUp()
        bridge = NativeBridge.shared
        bridge.reset()
    }

    override func tearDown() {
        bridge.reset()
        bridge = nil
        super.tearDown()
    }

    private func process(_ operation: String, _ args: [Any]) {
        bridge.processOperations([["op": operation, "args": args]])
    }

    private func installNativeCallbackResolver(
        _ handler: @escaping (Int, String?) -> Void
    ) async {
        let runtime = VueNativeMacOS.JSRuntime.shared
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
        let runtime = VueNativeMacOS.JSRuntime.shared
        runtime.jsQueue.sync {
            guard let context = runtime.context else { return }
            let resolver: @convention(block) (JSValue, JSValue, JSValue) -> Void = { _, _, _ in }
            context.setObject(
                resolver,
                forKeyedSubscript: "__VN_resolveCallback" as NSString
            )
        }
    }

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

        let firstContentView = FlippedView(
            frame: NSRect(x: 0, y: 0, width: 320, height: 240)
        )
        bridge.initialize(contentView: firstContentView)

        let staleModule = DelayedCallbackModule()
        VueNativeMacOS.NativeModuleRegistry.shared.register(staleModule)
        process(
            "invokeNativeModule",
            [staleModule.moduleName, "wait", [], 42]
        )
        XCTAssertEqual(staleModule.pendingCallbackCount, 1)

        let replacementContentView = FlippedView(
            frame: NSRect(x: 0, y: 0, width: 640, height: 480)
        )
        bridge.initialize(contentView: replacementContentView)

        let currentModule = DelayedCallbackModule()
        VueNativeMacOS.NativeModuleRegistry.shared.register(currentModule)
        process(
            "invokeNativeModule",
            [currentModule.moduleName, "wait", [], 42]
        )
        XCTAssertEqual(currentModule.pendingCallbackCount, 1)

        staleModule.completeNext(with: "stale")
        currentModule.completeNext(with: "current")

        await fulfillment(of: [resolved], timeout: 2)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(resolvedCallbackIDs, [42])
        XCTAssertEqual(resolvedValues, ["current"])
    }

    func testInsertBeforeMovesExistingChildWithoutDuplicatingIt() {
        process("create", [1, "VView"])
        process("create", [2, "VView"])
        process("create", [3, "VView"])
        process("appendChild", [1, 2])
        process("appendChild", [1, 3])

        process("insertBefore", [1, 3, 2])

        let parent = bridge.view(forNodeId: 1)!
        let first = bridge.view(forNodeId: 2)!
        let second = bridge.view(forNodeId: 3)!
        XCTAssertEqual(parent.subviews.first, second)
        XCTAssertEqual(parent.subviews.dropFirst().first, first)
        XCTAssertEqual(parent.subviews.filter { $0 === second }.count, 1)
    }

    func testReparentedChildSurvivesRemovingItsOldParent() {
        process("create", [1, "VView"])
        process("create", [2, "VView"])
        process("create", [3, "VView"])
        process("appendChild", [1, 3])
        process("appendChild", [2, 3])

        let newParent = bridge.view(forNodeId: 2)!
        let child = bridge.view(forNodeId: 3)!
        XCTAssertTrue(child.isDescendant(of: newParent))

        process("removeChild", [1])

        XCTAssertNotNil(bridge.view(forNodeId: 3))
        XCTAssertTrue(child.isDescendant(of: newParent))
    }

    func testInitializeWithNewHostClearsOldRootBeforeReplacingContentView() {
        let firstContentView = FlippedView(
            frame: NSRect(x: 0, y: 0, width: 320, height: 240)
        )
        bridge.initialize(contentView: firstContentView)

        process("create", [1, "__ROOT__"])
        process("setRootView", [1])
        let oldRoot = bridge.view(forNodeId: 1)
        XCTAssertTrue(oldRoot?.superview === firstContentView)

        let secondContentView = FlippedView(
            frame: NSRect(x: 0, y: 0, width: 640, height: 480)
        )
        bridge.initialize(contentView: secondContentView)

        XCTAssertEqual(bridge.registeredViewCount, 0)
        XCTAssertNil(oldRoot?.superview)
        XCTAssertTrue(firstContentView.subviews.isEmpty)

        process("create", [2, "__ROOT__"])
        process("setRootView", [2])
        XCTAssertTrue(bridge.view(forNodeId: 2)?.superview === secondContentView)
    }

    func testRemoveChildDestroysEachViewInSubtreeExactlyOnce() {
        let factory = DestroyProbeFactory()
        ComponentRegistry.shared.register("DestroyProbe", factory: factory)
        defer { ComponentRegistry.shared.unregister("DestroyProbe") }

        process("create", [201, "DestroyProbe"])
        process("create", [202, "DestroyProbe"])
        process("appendChild", [201, 202])

        process("removeChild", [201])
        process("removeChild", [201])

        let createdIDs = Set(factory.createdViews.map { ObjectIdentifier($0) })
        XCTAssertEqual(factory.destroyedViewIDs.count, 2)
        XCTAssertEqual(Set(factory.destroyedViewIDs), createdIDs)
    }

    func testMoveDoesNotDestroyViewAndResetDestroysItOnce() {
        let factory = DestroyProbeFactory()
        ComponentRegistry.shared.register("DestroyProbe", factory: factory)
        defer { ComponentRegistry.shared.unregister("DestroyProbe") }

        process("create", [211, "VView"])
        process("create", [212, "VView"])
        process("create", [213, "DestroyProbe"])
        process("appendChild", [211, 213])

        process("appendChild", [212, 213])

        XCTAssertTrue(factory.destroyedViewIDs.isEmpty, "Reparenting must not destroy a live node")

        bridge.reset()
        bridge.reset()

        XCTAssertEqual(factory.destroyedViewIDs.count, 1, "Reset must destroy each registered view once")
        XCTAssertEqual(factory.destroyedViewIDs.first, factory.createdViews.first.map { ObjectIdentifier($0) })
    }
}

@MainActor
private final class DestroyProbeFactory: NativeComponentFactory {
    private(set) var createdViews: [NSView] = []
    private(set) var destroyedViewIDs: [ObjectIdentifier] = []

    func createView() -> NSView {
        let view = NSView()
        createdViews.append(view)
        return view
    }

    func updateProp(view: NSView, key: String, value: Any?) {}

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {}

    func destroyView(view: NSView) {
        destroyedViewIDs.append(ObjectIdentifier(view))
    }
}

private final class DelayedCallbackModule: VueNativeShared.NativeModule {
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
