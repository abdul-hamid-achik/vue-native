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
}
