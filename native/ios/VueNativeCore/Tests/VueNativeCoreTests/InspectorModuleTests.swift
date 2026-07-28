#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Tests for the Inspector devtools module and the bridge's view-tree dump.
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

    // MARK: - Helper

    /// Invoke a module method and wait for its async callback.
    @discardableResult
    private func invoke(
        _ module: any NativeModule,
        _ method: String,
        args: [Any] = [],
        timeout: TimeInterval = 3
    ) -> (result: Any?, error: String?) {
        let completed = expectation(description: "\(module.moduleName).\(method)")
        var result: Any?
        var error: String?
        module.invoke(method: method, args: args) { value, callbackError in
            result = value
            error = callbackError
            completed.fulfill()
        }
        wait(for: [completed], timeout: timeout)
        return (result, error)
    }

    /// Depth-first search for a node dictionary with the given id in a forest.
    private func findNode(id: Int, in forest: [[String: Any]]) -> [String: Any]? {
        for node in forest {
            if let nodeId = node["id"] as? Int, nodeId == id {
                return node
            }
            if let children = node["children"] as? [[String: Any]],
               let match = findNode(id: id, in: children) {
                return match
            }
        }
        return nil
    }

    // MARK: - Tests

    func testModuleName() {
        XCTAssertEqual(InspectorModule(bridge: bridge).moduleName, "Inspector")
    }

    func testUnknownMethodReturnsError() {
        let result = invoke(InspectorModule(bridge: bridge), "doesNotExist")
        XCTAssertNil(result.result)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("Unknown method") ?? false)
    }

    func testDumpTreeReturnsRegisteredHierarchy() {
        // Build: VView(1) -> VText(2), VButton(3)
        bridge.processOperations([
            ["op": "create", "args": [1, "VView"]],
            ["op": "create", "args": [2, "VText"]],
            ["op": "create", "args": [3, "VButton"]],
            ["op": "appendChild", "args": [1, 2]],
            ["op": "appendChild", "args": [1, 3]],
        ])

        let result = invoke(InspectorModule(bridge: bridge), "dumpTree")

        XCTAssertNil(result.error, "dumpTree must be a recognized method")
        let forest = result.result as? [[String: Any]]
        XCTAssertNotNil(forest, "dumpTree should return an array of root nodes")

        // Node 1 is the only root (no parent).
        guard let root = findNode(id: 1, in: forest ?? []) else {
            return XCTFail("Expected node 1 in the dumped tree")
        }
        XCTAssertEqual(root["type"] as? String, "VView")

        let children = root["children"] as? [[String: Any]]
        XCTAssertEqual(children?.count, 2, "Node 1 should have two children")

        let childTypes = children?.compactMap { $0["type"] as? String }.sorted()
        XCTAssertEqual(childTypes, ["VButton", "VText"])

        // Children carry their own ids and an (empty) children array.
        let textChild = children?.first { ($0["id"] as? Int) == 2 }
        XCTAssertNotNil(textChild)
        XCTAssertEqual(textChild?["type"] as? String, "VText")
        XCTAssertEqual((textChild?["children"] as? [Any])?.count, 0)
    }

    func testDumpTreeIncludesFrameDictionary() {
        bridge.processOperations([
            ["op": "create", "args": [10, "VView"]],
        ])
        if let view = bridge.view(forNodeId: 10) {
            view.frame = CGRect(x: 1, y: 2, width: 30, height: 40)
        }

        let result = invoke(InspectorModule(bridge: bridge), "dumpTree")
        let forest = result.result as? [[String: Any]]
        guard let node = findNode(id: 10, in: forest ?? []) else {
            return XCTFail("Expected node 10 in the dumped tree")
        }

        let frame = node["frame"] as? [String: Any]
        XCTAssertNotNil(frame, "Each node should expose a frame dictionary")
        XCTAssertEqual(frame?["x"] as? CGFloat, 1)
        XCTAssertEqual(frame?["y"] as? CGFloat, 2)
        XCTAssertEqual(frame?["width"] as? CGFloat, 30)
        XCTAssertEqual(frame?["height"] as? CGFloat, 40)
    }

    func testDumpTreeEmptyWhenNoViews() {
        let result = invoke(InspectorModule(bridge: bridge), "dumpTree")
        XCTAssertNil(result.error)
        let forest = result.result as? [[String: Any]]
        XCTAssertEqual(forest?.count, 0, "An empty registry should dump an empty forest")
    }
}
#endif
