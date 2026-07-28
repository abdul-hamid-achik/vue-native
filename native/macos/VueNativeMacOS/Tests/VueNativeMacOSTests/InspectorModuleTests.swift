import AppKit
import XCTest
import VueNativeShared
@testable import VueNativeMacOS

/// Tests for the `Inspector` native module (`dumpTree`).
///
/// Views are registered through the real bridge (create / appendChild ops) and
/// the module walks the bridge's registry via `inspectionSnapshot()`, mirroring
/// how it is wired in production.
@MainActor
final class InspectorModuleTests: XCTestCase {

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

    // MARK: - Helpers

    private func process(_ op: String, _ args: [Any]) {
        bridge.processOperations([["op": op, "args": args]])
    }

    private func makeModule() -> InspectorModule {
        let bridge = self.bridge!
        return InspectorModule(nodeSnapshot: { bridge.inspectionSnapshot() })
    }

    private func dumpTree(_ module: InspectorModule) async -> (result: Any?, error: String?) {
        final class Box {
            var result: Any?
            var error: String? = "not_called"
        }
        let box = Box()
        let exp = expectation(description: "Inspector.dumpTree")
        module.invoke(method: "dumpTree", args: []) { result, error in
            box.result = result
            box.error = error
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 3)
        return (box.result, box.error)
    }

    // MARK: - Tests

    func testModuleName() {
        XCTAssertEqual(makeModule().moduleName, "Inspector")
    }

    func testDumpTreeReturnsRegisteredHierarchy() async {
        process("create", [1, "VView"])
        process("create", [2, "VButton"])
        process("create", [3, "VText"])
        process("appendChild", [1, 2])
        process("appendChild", [1, 3])

        let (result, error) = await dumpTree(makeModule())
        XCTAssertNil(error)

        guard let root = result as? [String: Any] else {
            return XCTFail("expected a dictionary root node, got \(String(describing: result))")
        }

        XCTAssertEqual(root["id"] as? Int, 1)
        XCTAssertEqual(root["type"] as? String, "VView")

        // Frame is always present with the documented keys.
        let frame = root["frame"] as? [String: Any]
        XCTAssertNotNil(frame)
        XCTAssertNotNil(frame?["x"])
        XCTAssertNotNil(frame?["y"])
        XCTAssertNotNil(frame?["width"])
        XCTAssertNotNil(frame?["height"])

        let children = root["children"] as? [[String: Any]]
        XCTAssertEqual(children?.count, 2)
        XCTAssertEqual(children?.compactMap { $0["id"] as? Int }.sorted(), [2, 3])
        XCTAssertEqual(children?.compactMap { $0["type"] as? String }.sorted(), ["VButton", "VText"])

        // Leaves carry an empty children array.
        let allLeavesEmpty = children?.allSatisfy { ($0["children"] as? [Any])?.isEmpty == true } ?? false
        XCTAssertTrue(allLeavesEmpty)
    }

    func testDumpTreeNestsGrandchildren() async {
        process("create", [10, "VView"])
        process("create", [11, "VView"])
        process("create", [12, "VText"])
        process("appendChild", [10, 11])
        process("appendChild", [11, 12])

        let (result, error) = await dumpTree(makeModule())
        XCTAssertNil(error)

        guard let root = result as? [String: Any] else {
            return XCTFail("expected a dictionary root node")
        }
        XCTAssertEqual(root["id"] as? Int, 10)

        let children = root["children"] as? [[String: Any]]
        XCTAssertEqual(children?.count, 1)
        XCTAssertEqual(children?.first?["id"] as? Int, 11)

        let grandchildren = children?.first?["children"] as? [[String: Any]]
        XCTAssertEqual(grandchildren?.first?["id"] as? Int, 12)
        XCTAssertEqual(grandchildren?.first?["type"] as? String, "VText")
    }

    func testDumpTreeWithNoViewsReturnsNull() async {
        let (result, error) = await dumpTree(makeModule())
        XCTAssertNil(error)
        XCTAssertNil(result)
    }

    func testDumpTreeResultIsValidJSON() async {
        process("create", [1, "VView"])
        process("create", [2, "VText"])
        process("appendChild", [1, 2])

        let (result, error) = await dumpTree(makeModule())
        XCTAssertNil(error)
        guard let result else { return XCTFail("expected a tree") }

        // The module round-trips through JSONSerialization, so the result must
        // itself be a valid JSON object.
        XCTAssertTrue(JSONSerialization.isValidJSONObject(result))
    }

    func testRejectsUnknownMethod() async {
        final class Box {
            var error: String? = "not_called"
        }
        let box = Box()
        let exp = expectation(description: "Inspector.unknown")
        makeModule().invoke(method: "definitelyNotAMethod", args: []) { _, error in
            box.error = error
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 3)
        XCTAssertTrue(box.error?.contains("Unknown method") == true)
    }
}
