import XCTest
@testable import VueNativeMacOS

@MainActor
final class VueNativeMacOSTests: XCTestCase {

    // MARK: - FlippedView

    func testFlippedViewIsFlipped() {
        let view = FlippedView()
        XCTAssertTrue(view.isFlipped, "FlippedView must have isFlipped = true")
        XCTAssertTrue(view.wantsLayer, "FlippedView must be layer-backed")
    }

    // MARK: - LayoutNode

    func testLayoutNodeDefaults() {
        let node = LayoutNode()
        XCTAssertEqual(node.flexDirection, .column)
        XCTAssertEqual(node.justifyContent, .flexStart)
        XCTAssertEqual(node.alignItems, .stretch)
        XCTAssertEqual(node.flexGrow, 0)
        XCTAssertEqual(node.flexShrink, 1)
        XCTAssertEqual(node.positionType, .relative)
        XCTAssertEqual(node.display, .flex)
    }

    func testLayoutValueResolvePoints() {
        let value = LayoutValue.points(50)
        XCTAssertEqual(value.resolve(relativeTo: 200), 50)
    }

    func testLayoutValueResolvePercent() {
        let value = LayoutValue.percent(50)
        XCTAssertEqual(value.resolve(relativeTo: 200), 100)
    }

    func testLayoutValueResolveAuto() {
        let value = LayoutValue.auto
        XCTAssertNil(value.resolve(relativeTo: 200))
    }

    func testLayoutValueResolveUndefined() {
        let value = LayoutValue.undefined
        XCTAssertNil(value.resolve(relativeTo: 200))
        XCTAssertTrue(value.isUndefined)
    }

    func testEdgeInsetsZero() {
        let insets = EdgeInsets.zero
        XCTAssertEqual(insets.horizontal, 0)
        XCTAssertEqual(insets.vertical, 0)
    }

    // MARK: - NSView LayoutNode Extension

    func testNSViewLayoutNodeAssociation() {
        let view = FlippedView()
        XCTAssertNil(view.layoutNode)

        let node = view.ensureLayoutNode()
        XCTAssertNotNil(view.layoutNode)
        XCTAssertTrue(node === view.layoutNode)
    }

    // MARK: - Percentage Operator

    func testPercentageOperator() {
        let value: LayoutValue = 50%
        XCTAssertEqual(value, .percent(50))
    }

    // MARK: - Basic Layout

    func testSimpleColumnLayout() {
        let parent = FlippedView(frame: NSRect(x: 0, y: 0, width: 200, height: 400))
        let parentNode = parent.ensureLayoutNode()
        parentNode.flexDirection = .column
        parentNode.width = .points(200)
        parentNode.height = .points(400)

        let child1 = FlippedView()
        let child1Node = child1.ensureLayoutNode()
        child1Node.height = .points(100)
        child1Node.width = .points(200)
        parent.addSubview(child1)

        let child2 = FlippedView()
        let child2Node = child2.ensureLayoutNode()
        child2Node.height = .points(100)
        child2Node.width = .points(200)
        parent.addSubview(child2)

        parentNode.layout(availableWidth: 200, availableHeight: 400)

        XCTAssertEqual(child1.frame.origin.y, 0)
        XCTAssertEqual(child2.frame.origin.y, 100)
    }

    func testFlexGrow() {
        let parent = FlippedView(frame: NSRect(x: 0, y: 0, width: 200, height: 400))
        let parentNode = parent.ensureLayoutNode()
        parentNode.flexDirection = .column
        parentNode.width = .points(200)
        parentNode.height = .points(400)

        let child1 = FlippedView()
        let child1Node = child1.ensureLayoutNode()
        child1Node.flexGrow = 1
        parent.addSubview(child1)

        let child2 = FlippedView()
        let child2Node = child2.ensureLayoutNode()
        child2Node.flexGrow = 1
        parent.addSubview(child2)

        parentNode.layout(availableWidth: 200, availableHeight: 400)

        // Both children should share space equally
        XCTAssertEqual(child1.frame.size.height, 200, accuracy: 1)
        XCTAssertEqual(child2.frame.size.height, 200, accuracy: 1)
    }

    // MARK: - NSColor+Hex

    func testColorFromHex6() {
        let color = NSColor.fromHex("#FF0000")
        XCTAssertNotNil(color)
        // Should be red
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
    }

    func testColorFromHexNamed() {
        let transparent = NSColor.fromHex("transparent")
        XCTAssertEqual(transparent, .clear)

        let white = NSColor.fromHex("white")
        XCTAssertEqual(white, .white)
    }

    func testColorFromHexInvalid() {
        let color = NSColor.fromHex("notacolor")
        XCTAssertEqual(color, .clear)
    }
}
