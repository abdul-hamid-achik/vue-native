import XCTest
@testable import VueNativeMacOS

/// Flexbox behaviour tests for the custom LayoutNode engine: direction,
/// justify/align, percent dimensions, gap, flex grow, and stretch semantics.
@MainActor
final class LayoutNodeTests: XCTestCase {

    // MARK: - Helpers

    /// A fixed-size flex container with a LayoutNode attached.
    private func makeContainer(
        width: CGFloat,
        height: CGFloat,
        direction: FlexDirection = .column
    ) -> FlippedView {
        let view = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        let node = view.ensureLayoutNode()
        node.flexDirection = direction
        node.width = .points(width)
        node.height = .points(height)
        return view
    }

    /// Adds a child with a LayoutNode to the container and returns its node.
    @discardableResult
    private func addChild(to parent: NSView) -> LayoutNode {
        let child = FlippedView()
        let node = child.ensureLayoutNode()
        parent.addSubview(child)
        return node
    }

    // MARK: - Direction

    func testColumnLayoutStacksVertically() {
        let parent = makeContainer(width: 200, height: 400, direction: .column)
        let c1 = addChild(to: parent)
        c1.width = .points(200); c1.height = .points(100)
        let c2 = addChild(to: parent)
        c2.width = .points(200); c2.height = .points(120)

        parent.layoutNode?.layout(availableWidth: 200, availableHeight: 400)

        XCTAssertEqual(c1.view?.frame.origin.y ?? -1, 0)
        XCTAssertEqual(c2.view?.frame.origin.y ?? -1, 100)
        XCTAssertEqual(c2.view?.frame.size.height ?? -1, 120)
    }

    func testRowLayoutStacksHorizontally() {
        let parent = makeContainer(width: 400, height: 100, direction: .row)
        let c1 = addChild(to: parent)
        c1.width = .points(100); c1.height = .points(100)
        let c2 = addChild(to: parent)
        c2.width = .points(150); c2.height = .points(100)

        parent.layoutNode?.layout(availableWidth: 400, availableHeight: 100)

        XCTAssertEqual(c1.view?.frame.origin.x ?? -1, 0)
        XCTAssertEqual(c2.view?.frame.origin.x ?? -1, 100)
        XCTAssertEqual(c2.view?.frame.size.width ?? -1, 150)
    }

    func testRowReverseReordersChildren() {
        let parent = makeContainer(width: 300, height: 100, direction: .rowReverse)
        let c1 = addChild(to: parent)
        c1.width = .points(100); c1.height = .points(100)
        let c2 = addChild(to: parent)
        c2.width = .points(100); c2.height = .points(100)

        parent.layoutNode?.layout(availableWidth: 300, availableHeight: 100)

        // In row-reverse the first child is placed at the trailing edge.
        let x1 = c1.view?.frame.origin.x ?? -1
        let x2 = c2.view?.frame.origin.x ?? -1
        XCTAssertGreaterThan(x1, x2)
    }

    // MARK: - Percent / auto dimensions

    func testPercentWidthResolvesAgainstParent() {
        let parent = makeContainer(width: 200, height: 100)
        let child = addChild(to: parent)
        child.width = .percent(50)
        child.height = .points(40)

        parent.layoutNode?.layout(availableWidth: 200, availableHeight: 100)

        XCTAssertEqual(child.view?.frame.size.width ?? -1, 100, accuracy: 0.5)
    }

    func testPercentHeightResolvesAgainstParent() {
        let parent = makeContainer(width: 100, height: 400)
        let child = addChild(to: parent)
        child.width = .points(50)
        child.height = .percent(25)

        parent.layoutNode?.layout(availableWidth: 100, availableHeight: 400)

        XCTAssertEqual(child.view?.frame.size.height ?? -1, 100, accuracy: 0.5)
    }

    func testAutoWidthFillsAvailableSpace() {
        let parent = makeContainer(width: 320, height: 100)
        let child = addChild(to: parent)
        child.width = .auto
        child.height = .points(50)

        parent.layoutNode?.layout(availableWidth: 320, availableHeight: 100)

        // Default align-items is stretch; an auto cross-axis size fills the parent.
        XCTAssertEqual(child.view?.frame.size.width ?? -1, 320, accuracy: 0.5)
    }

    // MARK: - Stretch semantics

    func testStretchAppliesOnlyToAutoCrossAxis() {
        // A definite cross-axis size must win over align-items: stretch, matching
        // CSS/Yoga behaviour on iOS and Android.
        let parent = makeContainer(width: 200, height: 100, direction: .column)

        let explicit = addChild(to: parent)
        explicit.width = .points(80)
        explicit.height = .points(40)

        let auto = addChild(to: parent)
        auto.height = .points(40) // width left undefined -> should stretch

        parent.layoutNode?.layout(availableWidth: 200, availableHeight: 100)

        XCTAssertEqual(explicit.view?.frame.size.width ?? -1, 80, accuracy: 0.5,
                       "explicit cross size must not be stretched")
        XCTAssertEqual(auto.view?.frame.size.width ?? -1, 200, accuracy: 0.5,
                       "auto cross size must stretch to the parent")
    }

    // MARK: - Justify / gap / grow

    func testJustifyContentCenter() {
        let parent = makeContainer(width: 200, height: 400)
        parent.layoutNode?.justifyContent = .center
        let child = addChild(to: parent)
        child.width = .points(100); child.height = .points(100)

        parent.layoutNode?.layout(availableWidth: 200, availableHeight: 400)

        XCTAssertEqual(child.view?.frame.origin.y ?? -1, 150, accuracy: 0.5)
    }

    func testGapBetweenChildren() {
        let parent = makeContainer(width: 200, height: 400)
        parent.layoutNode?.gap = 10
        let c1 = addChild(to: parent)
        c1.width = .points(200); c1.height = .points(50)
        let c2 = addChild(to: parent)
        c2.width = .points(200); c2.height = .points(50)

        parent.layoutNode?.layout(availableWidth: 200, availableHeight: 400)

        XCTAssertEqual(c1.view?.frame.origin.y ?? -1, 0, accuracy: 0.5)
        XCTAssertEqual(c2.view?.frame.origin.y ?? -1, 60, accuracy: 0.5)
    }

    func testFlexGrowDistributesFreeSpace() {
        let parent = makeContainer(width: 200, height: 400)
        let c1 = addChild(to: parent)
        c1.flexGrow = 1
        let c2 = addChild(to: parent)
        c2.flexGrow = 1

        parent.layoutNode?.layout(availableWidth: 200, availableHeight: 400)

        XCTAssertEqual(c1.view?.frame.size.height ?? -1, 200, accuracy: 0.5)
        XCTAssertEqual(c2.view?.frame.size.height ?? -1, 200, accuracy: 0.5)
    }

    // MARK: - Relayout on available-size change

    func testAvailableSizeChangeReResolvesPercentChild() {
        // Parent fills its available width (no fixed width) so a size change
        // must propagate to a percent-sized child.
        let parent = FlippedView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        let parentNode = parent.ensureLayoutNode()
        parentNode.flexDirection = .column
        parentNode.height = .points(100) // width left undefined -> resolves to availableWidth

        let child = FlippedView()
        let childNode = child.ensureLayoutNode()
        childNode.width = .percent(50)
        childNode.height = .points(50)
        parent.addSubview(child)

        parentNode.layout(availableWidth: 200, availableHeight: 100)
        XCTAssertEqual(child.frame.size.width, 100, accuracy: 0.5)

        // A wider available size must re-resolve the percent width.
        parentNode.layout(availableWidth: 300, availableHeight: 100)
        XCTAssertEqual(child.frame.size.width, 150, accuracy: 0.5)
    }
}
