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

    func testUpdatePropWithStyleDictDoesNotCrash() {
        let factory = VRefreshControlFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "style", value: [
            "backgroundColor": "#ff0000",
            "padding": 8,
            "width": 100,
        ])

        XCTAssertTrue(view.isHidden, "the stub placeholder stays hidden regardless of style props")
    }

    func testUpdatePropWithFlattenedStyleKeysDoesNotCrash() {
        // Mirrors how the bridge actually delivers a style object on iOS:
        // one call per key. macOS's stub factory ignores all of them.
        let factory = VRefreshControlFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "backgroundColor", value: "#ff0000")
        factory.updateProp(view: view, key: "padding", value: 8)
        factory.updateProp(view: view, key: "opacity", value: 0.5)
        factory.updateProp(view: view, key: "refreshing", value: true)

        XCTAssertTrue(view.isHidden)
    }
}
#endif
