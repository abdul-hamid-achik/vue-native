#if canImport(AppKit)
import XCTest
import AppKit
@testable import VueNativeMacOS

/// Regression coverage for the `style` prop now reaching native factories
/// (previously dropped before it left TS). `VRefreshControlFactory` is a
/// macOS stub -- pull-to-refresh does not exist on desktop -- so
/// `updateProp` is a total no-op regardless of key. This locks in that no
/// key (style-shaped or otherwise) crashes or mutates the placeholder view.
@MainActor
final class VRefreshControlFactoryTests: XCTestCase {

    func testUpdatePropWithStyleDictIsIgnoredByTheStub() {
        let factory = VRefreshControlFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "style", value: [
            "backgroundColor": "#ff0000",
            "padding": 8,
            "width": 100,
        ])

        XCTAssertTrue(view.isHidden, "the stub placeholder stays hidden regardless of style props")
        // `updateProp` is a total no-op, so the placeholder must still be in the
        // exact state `createView()` left it in. These are absolute values (not
        // "unchanged"), which is what makes them a real assertion: had the stub
        // fallen through to `StyleEngine`, `width` would be `.points(100)` and
        // `padding` non-zero.
        XCTAssertEqual(view.frame, .zero, "the placeholder must not be resized by a style dict")
        XCTAssertEqual(view.alphaValue, 1.0, "the placeholder must not be faded by a style dict")
        XCTAssertEqual(view.layoutNode?.width, .points(0), "a style-dict width must not reach the LayoutNode")
        XCTAssertEqual(view.layoutNode?.height, .points(0))
        XCTAssertEqual(view.layoutNode?.padding, .zero, "a style-dict padding must not reach the LayoutNode")
    }

    func testUpdatePropWithFlattenedStyleKeysIsIgnoredByTheStub() {
        // Mirrors how the bridge actually delivers a style object on iOS:
        // one call per key. macOS's stub factory ignores all of them.
        let factory = VRefreshControlFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "backgroundColor", value: "#ff0000")
        factory.updateProp(view: view, key: "padding", value: 8)
        factory.updateProp(view: view, key: "opacity", value: 0.5)
        factory.updateProp(view: view, key: "refreshing", value: true)

        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(view.frame, .zero, "flattened layout keys must not resize the placeholder")
        XCTAssertEqual(view.alphaValue, 1.0, "'opacity' must not reach the placeholder")
        XCTAssertEqual(view.layoutNode?.width, .points(0))
        XCTAssertEqual(view.layoutNode?.height, .points(0))
        XCTAssertEqual(view.layoutNode?.padding, .zero, "'padding' must not reach the LayoutNode")

        // Control: the same keys really are style keys — handed to the engine
        // the placeholder deliberately does not call, they land.
        let control = FlippedView()
        control.ensureLayoutNode()
        StyleEngine.apply(key: "padding", value: 8, to: control)
        StyleEngine.apply(key: "opacity", value: 0.5, to: control)
        XCTAssertEqual(control.alphaValue, 0.5, "sanity check: 'opacity' is a real style key")
        XCTAssertNotEqual(control.layoutNode?.padding, .zero, "sanity check: 'padding' is a real style key")
    }
}
#endif
