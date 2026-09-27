#if canImport(AppKit)
import AppKit
import XCTest
@testable import VueNativeMacOS

/// Regression coverage for the `LayoutNode` content-measurement hook, the
/// single-resolution rule for percentages, and the flexbox cases that used to be
/// wrong (reverse main-axis distribution, min/max redistribution, aspect ratio,
/// auto cross-axis sizing).
///
/// The pre-existing `LayoutNodeTests` suite sets an explicit `width`/`height` on
/// every node, so it could not see any of these: an auto-sized child silently
/// resolved to a zero main-axis size.
@MainActor
final class LayoutMeasureTests: XCTestCase {

    // MARK: - Helpers

    private func makeContainer(
        width: CGFloat?,
        height: CGFloat?,
        direction: FlexDirection = .column
    ) -> FlippedView {
        let view = FlippedView(frame: NSRect(
            x: 0, y: 0,
            width: width ?? 0,
            height: height ?? 0
        ))
        let node = view.ensureLayoutNode()
        node.flexDirection = direction
        if let width { node.width = .points(width) }
        if let height { node.height = .points(height) }
        return view
    }

    @discardableResult
    private func addBox(to parent: NSView) -> (NSView, LayoutNode) {
        let child = FlippedView()
        let node = child.ensureLayoutNode()
        parent.addSubview(child)
        return (child, node)
    }

    /// A real `VText` view, created through its factory so the measure hook the
    /// factory installs is the one under test.
    @discardableResult
    private func addText(
        _ text: String,
        to parent: NSView,
        fontSize: Double = 13,
        fontWeight: String? = nil
    ) -> (NSView, LayoutNode) {
        let factory = VTextFactory()
        let label = factory.createView()
        factory.updateProp(view: label, key: "fontSize", value: fontSize)
        if let fontWeight {
            factory.updateProp(view: label, key: "fontWeight", value: fontWeight)
        }
        factory.updateProp(view: label, key: "text", value: text)
        parent.addSubview(label)
        return (label, label.layoutNode!)
    }

    // MARK: - #1 Content measurement (auto main axis)

    /// The headline bug: a `VText` with no explicit `height` — e.g.
    /// `examples/counter`'s `greeting` style, which only sets
    /// fontSize/fontWeight/color/marginBottom — used to resolve to a zero-height
    /// main axis and render invisible.
    func testTextWithoutExplicitHeightGetsContentDerivedFrame() {
        let parent = makeContainer(width: 320, height: 600)
        let (label, node) = addText("Hello World", to: parent)

        parent.layoutNode?.layout(availableWidth: 320, availableHeight: 600)

        XCTAssertGreaterThan(node.computedFrame.height, 0, "auto-sized text must not collapse to zero height")
        XCTAssertGreaterThan(label.frame.height, 0, "the label's frame must carry the measured height")
        // 13pt system font → one 16pt line.
        XCTAssertEqual(node.computedFrame.height, 16, accuracy: 4)
        XCTAssertEqual(node.computedFrame.width, 320, accuracy: 0.5, "default align-items: stretch still fills the cross axis")
    }

    /// Larger/bolder text must measure larger — the frame is derived from the
    /// content, not a constant.
    func testMeasuredHeightTracksFontSize() {
        let parent = makeContainer(width: 320, height: 600)
        let (_, small) = addText("Counter", to: parent, fontSize: 13)
        let (_, large) = addText("Counter", to: parent, fontSize: 48, fontWeight: "bold")

        parent.layoutNode?.layout(availableWidth: 320, availableHeight: 600)

        XCTAssertGreaterThan(small.computedFrame.height, 0)
        XCTAssertGreaterThan(large.computedFrame.height, small.computedFrame.height * 1.5,
                             "48pt bold text must measure materially taller than 13pt")
    }

    /// The counter-app greeting case end to end: a column with a text child that
    /// only carries font styles plus a bottom margin.
    func testCounterGreetingStyleIsVisible() {
        let parent = makeContainer(width: 320, height: 480)
        let (_, greeting) = addText("Welcome to Vue Native", to: parent, fontSize: 24, fontWeight: "bold")
        greeting.margin = EdgeInsets(top: 0, right: 0, bottom: 16, left: 0)

        let (_, sibling) = addBox(to: parent)
        sibling.height = .points(40)

        parent.layoutNode?.layout(availableWidth: 320, availableHeight: 480)

        XCTAssertGreaterThan(greeting.computedFrame.height, 0, "greeting must be visible")
        XCTAssertEqual(sibling.computedFrame.origin.y,
                       greeting.computedFrame.maxY + 16,
                       accuracy: 0.5,
                       "the sibling must sit below the measured greeting plus its margin")
    }

    /// An explicit `measure` closure is the hook contract itself.
    func testCustomMeasureHookDrivesMainAxis() {
        let parent = makeContainer(width: 200, height: 400)
        let (_, node) = addBox(to: parent)
        node.measure = { _ in CGSize(width: 50, height: 30) }

        parent.layoutNode?.layout(availableWidth: 200, availableHeight: 400)

        XCTAssertEqual(node.computedFrame.height, 30, accuracy: 0.5)
    }

    /// Wrapping text measures against the available cross size, so the same
    /// string is taller in a narrow container.
    func testWrappingTextGrowsTallerInNarrowContainer() {
        let long = "The quick brown fox jumps over the lazy dog and keeps on running"

        let wide = makeContainer(width: 600, height: 400)
        let (_, wideNode) = addText(long, to: wide)
        wide.layoutNode?.layout(availableWidth: 600, availableHeight: 400)

        let narrow = makeContainer(width: 100, height: 400)
        let (_, narrowNode) = addText(long, to: narrow)
        narrow.layoutNode?.layout(availableWidth: 100, availableHeight: 400)

        XCTAssertGreaterThan(narrowNode.computedFrame.height, wideNode.computedFrame.height,
                             "text wrapped into 100pt must be taller than the same text in 600pt")
        XCTAssertLessThanOrEqual(narrowNode.computedFrame.width, 100.5,
                                 "measured cross size must be capped by the container")
    }

    /// An explicit size always beats the measure hook.
    func testExplicitHeightWinsOverMeasureHook() {
        let parent = makeContainer(width: 200, height: 400)
        let (label, node) = addText("Hello", to: parent)
        node.height = .points(42)

        parent.layoutNode?.layout(availableWidth: 200, availableHeight: 400)

        XCTAssertEqual(node.computedFrame.height, 42, accuracy: 0.5)
        XCTAssertNotNil(label.layoutNode?.measure, "the factory must still install the hook")
    }

    /// A plain container has no bottom-up sizing in this engine, so it must keep
    /// contributing zero and leave flex grow/shrink exactly as it was.
    func testPlainContainerStillContributesZeroBasis() {
        let parent = makeContainer(width: 200, height: 400)
        let (_, a) = addBox(to: parent)
        a.flexGrow = 1
        addBox(to: parent) // filler child with subviews would change nothing
        let (_, b) = addBox(to: parent)
        b.flexGrow = 1

        parent.layoutNode?.layout(availableWidth: 200, availableHeight: 400)

        XCTAssertEqual(a.computedFrame.height, 200, accuracy: 0.5)
        XCTAssertEqual(b.computedFrame.height, 200, accuracy: 0.5)
    }

    // MARK: - #2 Percentages must resolve once

    /// Phase 5 used to hand the already-resolved width back into
    /// `layout(availableWidth:)`, which re-resolved the child's own `.percent(50)`
    /// against it — so a grandchild laid out at 25% of the grandparent and the
    /// error compounded per level.
    func testNestedPercentWidthsDoNotCompound() {
        let root = makeContainer(width: 400, height: 400)
        let (_, level1) = addBox(to: root)
        level1.width = 50%
        level1.height = .points(300)

        let child1 = FlippedView()
        let level2 = child1.ensureLayoutNode()
        level2.width = 50%
        level2.height = .points(200)
        level1.view?.addSubview(child1)

        let child2 = FlippedView()
        let level3 = child2.ensureLayoutNode()
        level3.width = 50%
        level3.height = .points(100)
        child1.addSubview(child2)

        root.layoutNode?.layout(availableWidth: 400, availableHeight: 400)

        XCTAssertEqual(level1.computedFrame.width, 200, accuracy: 0.5, "50% of 400")
        XCTAssertEqual(level2.computedFrame.width, 100, accuracy: 0.5, "50% of 200, not 25% of 400")
        XCTAssertEqual(level3.computedFrame.width, 50, accuracy: 0.5, "50% of 100")
    }

    /// Same rule on the main axis of a column: a percent height must resolve
    /// against the parent's resolved height only once.
    func testNestedPercentHeightsDoNotCompound() {
        let root = makeContainer(width: 200, height: 400)
        let (_, level1) = addBox(to: root)
        level1.height = 50% // 200
        level1.width = .points(200)

        let child = FlippedView()
        let level2 = child.ensureLayoutNode()
        level2.height = 50% // 100 of level1's 200
        level2.width = .points(200)
        level1.view?.addSubview(child)

        root.layoutNode?.layout(availableWidth: 200, availableHeight: 400)

        XCTAssertEqual(level1.computedFrame.height, 200, accuracy: 0.5)
        XCTAssertEqual(level2.computedFrame.height, 100, accuracy: 0.5)
    }

    /// Padding must not leak into the percentage base twice either.
    func testPercentWidthResolvesAgainstParentContentBox() {
        let root = makeContainer(width: 200, height: 200)
        root.layoutNode?.padding = EdgeInsets(top: 0, right: 20, bottom: 0, left: 20)
        let (_, level1) = addBox(to: root)
        level1.width = 50% // 50% of the 160pt content box
        level1.height = .points(50)

        let child = FlippedView()
        let level2 = child.ensureLayoutNode()
        level2.width = 50%
        level2.height = .points(20)
        level1.view?.addSubview(child)

        root.layoutNode?.layout(availableWidth: 200, availableHeight: 200)

        XCTAssertEqual(level1.computedFrame.width, 80, accuracy: 0.5)
        XCTAssertEqual(level2.computedFrame.width, 40, accuracy: 0.5)
    }

    // MARK: - #16 Reverse main-axis distribution (golden frames)

    /// In `row-reverse` main-start is the RIGHT edge, so `flex-start` packs
    /// children against the right and the first child is nearest it.
    func testRowReverseFlexStartPacksAgainstRightEdge() {
        let parent = makeContainer(width: 300, height: 100, direction: .rowReverse)
        let (_, c1) = addBox(to: parent)
        c1.width = .points(50); c1.height = .points(50)
        let (_, c2) = addBox(to: parent)
        c2.width = .points(50); c2.height = .points(50)

        parent.layoutNode?.layout(availableWidth: 300, availableHeight: 100)

        XCTAssertEqual(c1.computedFrame, CGRect(x: 250, y: 0, width: 50, height: 50))
        XCTAssertEqual(c2.computedFrame, CGRect(x: 200, y: 0, width: 50, height: 50))
    }

    /// `flex-end` in a reversed direction means the main-END edge, i.e. the left.
    func testRowReverseFlexEndPacksAgainstLeftEdge() {
        let parent = makeContainer(width: 300, height: 100, direction: .rowReverse)
        parent.layoutNode?.justifyContent = .flexEnd
        let (_, c1) = addBox(to: parent)
        c1.width = .points(50); c1.height = .points(50)
        let (_, c2) = addBox(to: parent)
        c2.width = .points(50); c2.height = .points(50)

        parent.layoutNode?.layout(availableWidth: 300, availableHeight: 100)

        XCTAssertEqual(c1.computedFrame, CGRect(x: 50, y: 0, width: 50, height: 50))
        XCTAssertEqual(c2.computedFrame, CGRect(x: 0, y: 0, width: 50, height: 50))
    }

    /// `center` is symmetric, so the golden frames match the non-reversed case.
    func testRowReverseCenterIsSymmetric() {
        let parent = makeContainer(width: 300, height: 100, direction: .rowReverse)
        parent.layoutNode?.justifyContent = .center
        let (_, c1) = addBox(to: parent)
        c1.width = .points(50); c1.height = .points(50)
        let (_, c2) = addBox(to: parent)
        c2.width = .points(50); c2.height = .points(50)

        parent.layoutNode?.layout(availableWidth: 300, availableHeight: 100)

        XCTAssertEqual(c1.computedFrame, CGRect(x: 150, y: 0, width: 50, height: 50))
        XCTAssertEqual(c2.computedFrame, CGRect(x: 100, y: 0, width: 50, height: 50))
    }

    /// `column-reverse`: main-start is the BOTTOM edge.
    func testColumnReverseFlexStartPacksAgainstBottomEdge() {
        let parent = makeContainer(width: 100, height: 300, direction: .columnReverse)
        let (_, c1) = addBox(to: parent)
        c1.width = .points(50); c1.height = .points(50)
        let (_, c2) = addBox(to: parent)
        c2.width = .points(50); c2.height = .points(50)

        parent.layoutNode?.layout(availableWidth: 100, availableHeight: 300)

        XCTAssertEqual(c1.computedFrame, CGRect(x: 0, y: 250, width: 50, height: 50))
        XCTAssertEqual(c2.computedFrame, CGRect(x: 0, y: 200, width: 50, height: 50))
    }

    func testColumnReverseFlexEndPacksAgainstTopEdge() {
        let parent = makeContainer(width: 100, height: 300, direction: .columnReverse)
        parent.layoutNode?.justifyContent = .flexEnd
        let (_, c1) = addBox(to: parent)
        c1.width = .points(50); c1.height = .points(50)

        parent.layoutNode?.layout(availableWidth: 100, availableHeight: 300)

        XCTAssertEqual(c1.computedFrame, CGRect(x: 0, y: 0, width: 50, height: 50))
    }

    /// Non-reversed directions must be untouched by the reverse fix.
    func testRowFlexEndGoldenFrameIsUnchanged() {
        let parent = makeContainer(width: 300, height: 100, direction: .row)
        parent.layoutNode?.justifyContent = .flexEnd
        let (_, c1) = addBox(to: parent)
        c1.width = .points(50); c1.height = .points(50)
        let (_, c2) = addBox(to: parent)
        c2.width = .points(50); c2.height = .points(50)

        parent.layoutNode?.layout(availableWidth: 300, availableHeight: 100)

        XCTAssertEqual(c1.computedFrame, CGRect(x: 200, y: 0, width: 50, height: 50))
        XCTAssertEqual(c2.computedFrame, CGRect(x: 250, y: 0, width: 50, height: 50))
    }

    func testRowSpaceBetweenGoldenFrame() {
        let parent = makeContainer(width: 300, height: 100, direction: .row)
        parent.layoutNode?.justifyContent = .spaceBetween
        let (_, c1) = addBox(to: parent)
        c1.width = .points(50); c1.height = .points(50)
        let (_, c2) = addBox(to: parent)
        c2.width = .points(50); c2.height = .points(50)
        let (_, c3) = addBox(to: parent)
        c3.width = .points(50); c3.height = .points(50)

        parent.layoutNode?.layout(availableWidth: 300, availableHeight: 100)

        XCTAssertEqual(c1.computedFrame.origin.x, 0, accuracy: 0.5)
        XCTAssertEqual(c2.computedFrame.origin.x, 125, accuracy: 0.5)
        XCTAssertEqual(c3.computedFrame.origin.x, 250, accuracy: 0.5)
    }

    // MARK: - #16 min/max clamping must redistribute freed space

    /// A `maxWidth`-capped `flex: 1` sibling used to leave 50pt of dead space
    /// that CSS/Yoga hands to the other flexible sibling.
    func testMaxWidthCappedFlexSiblingGetsTheFreedSpace() {
        let parent = makeContainer(width: 300, height: 100, direction: .row)
        let (_, capped) = addBox(to: parent)
        capped.flexGrow = 1
        capped.maxWidth = .points(100)
        let (_, free) = addBox(to: parent)
        free.flexGrow = 1

        parent.layoutNode?.layout(availableWidth: 300, availableHeight: 100)

        XCTAssertEqual(capped.computedFrame.width, 100, accuracy: 0.5, "respects maxWidth")
        XCTAssertEqual(free.computedFrame.width, 200, accuracy: 0.5, "absorbs the freed space")
    }

    /// Redistribution must be weighted by flexGrow, not split evenly.
    /// 500pt across grow 1/1/3 → 100/100/300; the first is capped at 60, freeing
    /// 40pt which must go to the other two in a 1:3 ratio (110 / 330).
    func testFreedSpaceIsDistributedByGrowWeight() {
        let parent = makeContainer(width: 500, height: 100, direction: .row)
        let (_, capped) = addBox(to: parent)
        capped.flexGrow = 1
        capped.maxWidth = .points(60)
        let (_, one) = addBox(to: parent)
        one.flexGrow = 1
        let (_, three) = addBox(to: parent)
        three.flexGrow = 3

        parent.layoutNode?.layout(availableWidth: 500, availableHeight: 100)

        XCTAssertEqual(capped.computedFrame.width, 60, accuracy: 0.5)
        XCTAssertEqual(one.computedFrame.width, 110, accuracy: 0.5)
        XCTAssertEqual(three.computedFrame.width, 330, accuracy: 0.5)
        XCTAssertEqual(capped.computedFrame.width + one.computedFrame.width + three.computedFrame.width,
                       500, accuracy: 0.5, "no dead space may be left behind")
    }

    /// `minHeight` clamping must not be violated by the redistribution pass.
    func testMinHeightClampSurvivesRedistribution() {
        let parent = makeContainer(width: 100, height: 200)
        let (_, a) = addBox(to: parent)
        a.height = .points(150)
        let (_, b) = addBox(to: parent)
        b.height = .points(150)
        b.minHeight = .points(120)

        parent.layoutNode?.layout(availableWidth: 100, availableHeight: 200)

        XCTAssertGreaterThanOrEqual(b.computedFrame.height, 120)
        XCTAssertEqual(a.computedFrame.height + b.computedFrame.height, 200, accuracy: 0.5)
    }

    // MARK: - #16 aspect ratio

    /// CSS: a definite cross size wins over `aspect-ratio`. The old code applied
    /// the ratio unconditionally, so `width: 100, aspectRatio: 3` overrode the
    /// explicit width with `height * 3`.
    func testAspectRatioDoesNotOverrideDefiniteCrossSize() {
        let parent = makeContainer(width: 200, height: 400)
        let (_, node) = addBox(to: parent)
        node.width = .points(100)
        node.height = .points(50)
        node.aspectRatio = 3

        parent.layoutNode?.layout(availableWidth: 200, availableHeight: 400)

        XCTAssertEqual(node.computedFrame, CGRect(x: 0, y: 0, width: 100, height: 50))
    }

    /// When only the cross size is definite, the ratio derives the main size.
    func testAspectRatioDerivesMainFromDefiniteCrossSize() {
        let parent = makeContainer(width: 200, height: 400)
        let (_, node) = addBox(to: parent)
        node.width = .points(100)
        node.aspectRatio = 2 // column: height = width / 2

        parent.layoutNode?.layout(availableWidth: 200, availableHeight: 400)

        XCTAssertEqual(node.computedFrame.width, 100, accuracy: 0.5)
        XCTAssertEqual(node.computedFrame.height, 50, accuracy: 0.5)
    }

    /// Auto cross size still derives from the definite main size, as before.
    func testAspectRatioStillDerivesCrossFromMain() {
        let parent = makeContainer(width: 200, height: 400)
        let (_, node) = addBox(to: parent)
        node.height = .points(60)
        node.aspectRatio = 2 // column: width = height * 2

        parent.layoutNode?.layout(availableWidth: 200, availableHeight: 400)

        XCTAssertEqual(node.computedFrame.height, 60, accuracy: 0.5)
        XCTAssertEqual(node.computedFrame.width, 120, accuracy: 0.5)
    }

    // MARK: - #16 auto cross axis must size to content, not fill

    /// `alignItems: center` used to give an auto cross size the full parent
    /// width even for content-bearing children.
    func testAlignCenterSizesMeasuredChildToContent() {
        let parent = makeContainer(width: 320, height: 400)
        parent.layoutNode?.alignItems = .center
        let (_, node) = addText("Hi", to: parent)

        parent.layoutNode?.layout(availableWidth: 320, availableHeight: 400)

        XCTAssertGreaterThan(node.computedFrame.width, 0)
        XCTAssertLessThan(node.computedFrame.width, 320, "a two-character label must not stretch to the parent width")
        // Centered within the 320pt cross axis.
        XCTAssertEqual(node.computedFrame.origin.x,
                       (320 - node.computedFrame.width) / 2,
                       accuracy: 0.5)
    }

    /// Characterization test: a plain container has no bottom-up content sizing
    /// in this engine, so an auto cross size still fills the parent. Changing
    /// this needs real content-derived container sizing, not just this fix.
    func testAutoSizedPlainContainerStillFillsCrossAxis() {
        let parent = makeContainer(width: 320, height: 400)
        parent.layoutNode?.alignItems = .center
        let (_, node) = addBox(to: parent)
        node.height = .points(50)

        parent.layoutNode?.layout(availableWidth: 320, availableHeight: 400)

        XCTAssertEqual(node.computedFrame.width, 320, accuracy: 0.5)
    }

    /// `alignSelf: flexEnd` on measured content hugs the trailing edge at its
    /// own width instead of filling.
    func testAlignSelfFlexEndSizesMeasuredChildToContent() {
        let parent = makeContainer(width: 320, height: 400)
        let (_, node) = addText("Right-aligned", to: parent)
        node.alignSelf = .flexEnd

        parent.layoutNode?.layout(availableWidth: 320, availableHeight: 400)

        XCTAssertLessThan(node.computedFrame.width, 320)
        XCTAssertEqual(node.computedFrame.maxX, 320, accuracy: 0.5)
    }
}
#endif
