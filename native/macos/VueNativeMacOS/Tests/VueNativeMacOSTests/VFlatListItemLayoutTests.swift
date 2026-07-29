#if canImport(AppKit)
import AppKit
import XCTest
@testable import VueNativeMacOS

/// Tests for VFlatList variable-height item reporting: a `VView` carrying a
/// `__flatListIndex` prop and an `itemLayout` listener must emit `itemLayout` with
/// `{ "index": Int, "height": Double }` once its height is known, and only when the
/// height actually changes (to avoid feedback loops with the list's row sizing).
@MainActor
final class VFlatListItemLayoutTests: XCTestCase {

    // MARK: - Helpers

    /// Reference box so the (escaping) event handler can record payloads without
    /// capturing an `inout` parameter, which Swift disallows.
    private final class Collector {
        var payloads: [[String: Any]] = []
    }

    /// Build a VView item with a stored index and an `itemLayout` listener that records
    /// every payload it receives into `collector`.
    private func makeItem(index: Int?, collector: Collector) -> (factory: VViewFactory, view: NSView) {
        let factory = VViewFactory()
        let view = factory.createView()
        if let index {
            factory.updateProp(view: view, key: "__flatListIndex", value: index)
        }
        factory.addEventListener(view: view, event: "itemLayout") { payload in
            if let dict = payload as? [String: Any] { collector.payloads.append(dict) }
        }
        return (factory, view)
    }

    // MARK: - Emission

    func testItemLayoutEmittedOnLayout() {
        let collector = Collector()
        let (_, view) = makeItem(index: 3, collector: collector)

        view.frame = NSRect(x: 0, y: 0, width: 300, height: 80)
        view.layout()

        XCTAssertEqual(collector.payloads.count, 1, "layout should emit exactly one itemLayout")
        XCTAssertEqual(collector.payloads.first?["index"] as? Int, 3)
        XCTAssertEqual(collector.payloads.first?["height"] as? Double, 80.0)
    }

    func testItemLayoutUsesLayoutNodeComputedHeightWhenAvailable() {
        let collector = Collector()
        let (_, view) = makeItem(index: 0, collector: collector)

        // The flexbox-computed height wins over the raw frame height.
        view.layoutNode?.computedFrame = CGRect(x: 0, y: 0, width: 300, height: 132)
        view.frame = NSRect(x: 0, y: 0, width: 300, height: 1)
        view.layout()

        XCTAssertEqual(collector.payloads.first?["height"] as? Double, 132.0)
    }

    // MARK: - Loop guard (dedup)

    func testItemLayoutNotReemittedForUnchangedHeight() {
        let collector = Collector()
        let (_, view) = makeItem(index: 1, collector: collector)

        view.frame = NSRect(x: 0, y: 0, width: 300, height: 50)
        view.layout()
        view.layout()
        view.layout()

        XCTAssertEqual(collector.payloads.count, 1, "unchanged height must not re-emit (loop guard)")
    }

    func testItemLayoutEmittedAgainOnHeightChange() {
        let collector = Collector()
        let (_, view) = makeItem(index: 2, collector: collector)

        view.frame = NSRect(x: 0, y: 0, width: 300, height: 50)
        view.layout()

        view.frame = NSRect(x: 0, y: 0, width: 300, height: 120)
        view.layout()

        XCTAssertEqual(collector.payloads.count, 2, "a real height change must re-emit")
        XCTAssertEqual(collector.payloads.first?["height"] as? Double, 50.0)
        XCTAssertEqual(collector.payloads.last?["height"] as? Double, 120.0)
        XCTAssertEqual(collector.payloads.last?["index"] as? Int, 2)
    }

    // MARK: - Guard conditions

    func testNoEmissionWithoutIndex() {
        let collector = Collector()
        let (_, view) = makeItem(index: nil, collector: collector)

        view.frame = NSRect(x: 0, y: 0, width: 300, height: 80)
        view.layout()

        XCTAssertTrue(collector.payloads.isEmpty, "no index -> not a flat-list item -> no emission")
    }

    func testNoEmissionWithoutListener() {
        let factory = VViewFactory()
        let view = factory.createView()
        factory.updateProp(view: view, key: "__flatListIndex", value: 4)

        // No listener registered; layout must not crash and must store the index.
        view.frame = NSRect(x: 0, y: 0, width: 300, height: 80)
        view.layout()

        XCTAssertEqual(FlatListItemStorage.index(for: view), 4)
    }

    func testNoEmissionForZeroHeight() {
        let collector = Collector()
        let (_, view) = makeItem(index: 0, collector: collector)

        view.frame = NSRect(x: 0, y: 0, width: 300, height: 0)
        view.layout()

        XCTAssertTrue(collector.payloads.isEmpty, "zero height is not a meaningful measurement")
    }

    // MARK: - Listener lifecycle

    func testRemoveEventListenerStopsEmission() {
        let collector = Collector()
        let (factory, view) = makeItem(index: 5, collector: collector)

        view.frame = NSRect(x: 0, y: 0, width: 300, height: 80)
        view.layout()
        XCTAssertEqual(collector.payloads.count, 1)

        factory.removeEventListener(view: view, event: "itemLayout")

        view.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        view.layout()
        XCTAssertEqual(collector.payloads.count, 1, "removed listener must not receive further events")
    }

    // MARK: - Prop/listener arriving after layout (async re-report path)

    func testItemLayoutReportedWhenListenerArrivesAfterLayout() {
        let factory = VViewFactory()
        let view = factory.createView()

        // Layout is already done before the index/listener arrive.
        view.frame = NSRect(x: 0, y: 0, width: 300, height: 90)
        view.layout()

        factory.updateProp(view: view, key: "__flatListIndex", value: 7)

        let expectation = expectation(description: "itemLayout emitted asynchronously")
        factory.addEventListener(view: view, event: "itemLayout") { payload in
            guard let dict = payload as? [String: Any] else { return }
            XCTAssertEqual(dict["index"] as? Int, 7)
            XCTAssertEqual(dict["height"] as? Double, 90.0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Index coercion

    func testIndexCoercedFromNumberTypes() {
        let factory = VViewFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "__flatListIndex", value: NSNumber(value: 12))
        XCTAssertEqual(FlatListItemStorage.index(for: view), 12)

        factory.updateProp(view: view, key: "__flatListIndex", value: 9.0)
        XCTAssertEqual(FlatListItemStorage.index(for: view), 9)

        factory.updateProp(view: view, key: "__flatListIndex", value: "6")
        XCTAssertEqual(FlatListItemStorage.index(for: view), 6)
    }
}
#endif
