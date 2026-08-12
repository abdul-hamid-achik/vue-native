#if canImport(AppKit)
import XCTest
import AppKit
@testable import VueNativeMacOS

/// Tests for `VScrollViewFactory.layoutDocumentView(for:)`.
///
/// `documentView` sits behind `NSClipView` in the `NSScrollView` hierarchy,
/// and `LayoutNode.children` walks `view.subviews` directly -- which stops
/// at the (LayoutNode-less) clip view -- so the main `NativeBridge
/// .triggerLayout()` pass never reaches `documentView`'s children on its
/// own. `layoutDocumentView(for:)` is the post-layout pass that fixes this:
/// it lays out `documentView`'s children against a generous sentinel on the
/// scroll axis, then resizes `documentView` to the actual extent used.
@MainActor
final class VScrollViewFactoryTests: XCTestCase {

    private func makeChild(height: CGFloat) -> NSView {
        let view = FlippedView()
        let node = view.ensureLayoutNode()
        node.height = .points(height)
        node.width = .points(50)
        return view
    }

    /// Gives the scroll view a concrete frame and forces AppKit to lay out
    /// its internal clip view/scrollers immediately, without needing to be
    /// attached to a real window.
    private func makeScrollView(width: CGFloat, height: CGFloat) -> NSScrollView {
        let factory = VScrollViewFactory()
        let scrollView = factory.createView() as! NSScrollView
        scrollView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        scrollView.tile()
        return scrollView
    }

    // MARK: - Children reach documentView

    func testChildrenArePositionedInsideDocumentView() {
        let factory = VScrollViewFactory()
        let scrollView = makeScrollView(width: 200, height: 200)

        let first = makeChild(height: 100)
        let second = makeChild(height: 100)
        factory.insertChild(first, into: scrollView, before: nil)
        factory.insertChild(second, into: scrollView, before: nil)

        VScrollViewFactory.layoutDocumentView(for: scrollView)

        // Regression: before the fix these stayed at the FlippedView default
        // frame (.zero) because the recursive layout pass never reached them.
        XCTAssertEqual(first.frame, CGRect(x: 0, y: 0, width: 50, height: 100))
        XCTAssertEqual(second.frame, CGRect(x: 0, y: 100, width: 50, height: 100))
    }

    // MARK: - documentView grows to fit overflowing content

    func testDocumentViewGrowsToFitContentTallerThanViewport() {
        let factory = VScrollViewFactory()
        let scrollView = makeScrollView(width: 200, height: 200)

        for _ in 0..<3 {
            factory.insertChild(makeChild(height: 100), into: scrollView, before: nil)
        }

        VScrollViewFactory.layoutDocumentView(for: scrollView)

        // 3 * 100pt children > the 200pt viewport -- the document view must
        // grow to the full content extent so the scroller's range is correct.
        XCTAssertEqual(scrollView.documentView?.frame.height, 300)
        XCTAssertEqual(scrollView.documentView?.frame.width, scrollView.contentView.bounds.width)
    }

    func testDocumentViewNeverShrinksBelowViewportForSparseContent() {
        let factory = VScrollViewFactory()
        let scrollView = makeScrollView(width: 200, height: 200)

        factory.insertChild(makeChild(height: 20), into: scrollView, before: nil)

        VScrollViewFactory.layoutDocumentView(for: scrollView)

        // Content shorter than the viewport must not shrink the document
        // view below the visible area.
        XCTAssertEqual(scrollView.documentView?.frame.height, scrollView.contentView.bounds.height)
    }

    // MARK: - Horizontal scrolling

    func testHorizontalDocumentViewGrowsAlongWidth() {
        let factory = VScrollViewFactory()
        let scrollView = makeScrollView(width: 200, height: 200)
        factory.updateProp(view: scrollView, key: "horizontal", value: true)
        scrollView.tile()

        // `horizontal` only toggles the scroller chrome (mirroring
        // `updateProp`'s "horizontal" case) -- laying children out
        // side-by-side is still the app's responsibility via
        // `contentContainerStyle`, same as `flexDirection: "row"` on iOS/RN.
        scrollView.documentView?.layoutNode?.flexDirection = .row

        for _ in 0..<3 {
            let child = FlippedView()
            let node = child.ensureLayoutNode()
            node.width = .points(100)
            node.height = .points(50)
            factory.insertChild(child, into: scrollView, before: nil)
        }

        VScrollViewFactory.layoutDocumentView(for: scrollView)

        XCTAssertEqual(scrollView.documentView?.frame.width, 300)
        XCTAssertEqual(scrollView.documentView?.frame.height, scrollView.contentView.bounds.height)
    }

    // MARK: - Non-VScrollView document views are left alone

    func testTableViewBackedDocumentViewIsUntouched() {
        // Mirrors VList/VSectionList/VOutlineView: their documentView never
        // gets a LayoutNode, since they manage their own sizing.
        let scrollView = NSScrollView()
        scrollView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        let tableView = NSTableView()
        scrollView.documentView = tableView
        tableView.frame = CGRect(x: 0, y: 0, width: 123, height: 456)
        // `tile()` itself may normalize the document view's frame (e.g. to
        // track the clip view's width) independent of anything this factory
        // does -- snapshot *after* tile() so the assertion below isolates
        // `layoutDocumentView`'s own effect (none) rather than AppKit's.
        scrollView.tile()
        let frameAfterTile = tableView.frame

        VScrollViewFactory.layoutDocumentView(for: scrollView)

        XCTAssertEqual(tableView.frame, frameAfterTile, "no LayoutNode on the document view -- must be left untouched")
    }

    func testMissingDocumentViewDoesNotCrash() {
        let scrollView = NSScrollView()
        scrollView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        VScrollViewFactory.layoutDocumentView(for: scrollView)
    }

    func testZeroSizedViewportDoesNotCrash() {
        let factory = VScrollViewFactory()
        let scrollView = factory.createView() as! NSScrollView
        // Never given a frame -- viewport bounds stay zero.
        VScrollViewFactory.layoutDocumentView(for: scrollView)
    }
}
#endif
