import AppKit
import XCTest
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
