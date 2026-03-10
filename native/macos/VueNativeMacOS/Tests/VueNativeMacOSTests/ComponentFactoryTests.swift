import AppKit
import XCTest
@testable import VueNativeMacOS

@MainActor
final class ComponentFactoryTests: XCTestCase {

    func testVListFactoryAppliesPublicProps() {
        let factory = VListFactory()
        guard let container = factory.createView() as? VListContainerView else {
            return XCTFail("Expected VListContainerView")
        }

        factory.updateProp(view: container, key: "estimatedItemHeight", value: 72)
        factory.updateProp(view: container, key: "showsScrollIndicator", value: false)
        factory.updateProp(view: container, key: "bounces", value: false)

        XCTAssertEqual(container.estimatedItemHeight, 72)
        XCTAssertFalse(container.scrollView.hasVerticalScroller)
        XCTAssertEqual(container.scrollView.verticalScrollElasticity, .none)
        XCTAssertEqual(container.scrollView.horizontalScrollElasticity, .none)
    }

    func testVSectionListFactoryBuildsRowsFromInsertedChildren() {
        let factory = VSectionListFactory()
        guard let container = factory.createView() as? VSectionListContainerView else {
            return XCTFail("Expected VSectionListContainerView")
        }

        let header = FlippedView(frame: NSRect(x: 0, y: 0, width: 200, height: 28))
        header.ensureLayoutNode()
        StyleEngine.setInternalPropDirect("__sectionHeader", value: true, on: header)

        let item1 = FlippedView(frame: NSRect(x: 0, y: 0, width: 200, height: 44))
        item1.ensureLayoutNode()
        let item2 = FlippedView(frame: NSRect(x: 0, y: 0, width: 200, height: 44))
        item2.ensureLayoutNode()

        factory.insertChild(header, into: container, before: nil)
        factory.insertChild(item1, into: container, before: nil)
        factory.insertChild(item2, into: container, before: nil)

        XCTAssertEqual(container.numberOfRows(in: container.tableView), 3)
        XCTAssertTrue(container.tableView(container.tableView, isGroupRow: 0))
        XCTAssertFalse(container.tableView(container.tableView, isGroupRow: 1))
    }

    func testVSectionListFactoryEmitsFlatScrollPayload() {
        let factory = VSectionListFactory()
        guard let container = factory.createView() as? VSectionListContainerView else {
            return XCTFail("Expected VSectionListContainerView")
        }

        var payload: [String: Any]?
        factory.addEventListener(view: container, event: "scroll") { eventPayload in
            payload = eventPayload as? [String: Any]
        }

        container.scrollView.frame = NSRect(x: 0, y: 0, width: 120, height: 240)
        container.tableView.frame = NSRect(x: 0, y: 0, width: 240, height: 960)
        container.scrollView.contentView.scroll(to: NSPoint(x: 12, y: 34))
        NotificationCenter.default.post(
            name: NSView.boundsDidChangeNotification,
            object: container.scrollView.contentView
        )

        guard let payload else {
            return XCTFail("Expected scroll payload")
        }

        XCTAssertEqual(payload["x"] as? CGFloat, 12)
        XCTAssertEqual(payload["y"] as? CGFloat, 34)
        XCTAssertEqual(payload["contentWidth"] as? CGFloat, 240)
        XCTAssertEqual(payload["contentHeight"] as? CGFloat, 960)
        XCTAssertEqual(payload["layoutWidth"] as? CGFloat, 120)
        XCTAssertEqual(payload["layoutHeight"] as? CGFloat, 240)
        XCTAssertNil(payload["contentOffset"])
        XCTAssertNil(payload["layoutMeasurement"])
    }
}
