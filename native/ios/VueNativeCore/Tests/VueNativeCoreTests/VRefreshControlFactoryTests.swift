#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Regression coverage for the `style` prop now reaching native factories
/// (previously dropped before it left TS). `VRefreshControlFactory`'s wrapper
/// view is a zero-size, hidden placeholder -- the visible widget is the
/// `UIRefreshControl` attached to the parent scroll view -- so style props
/// have no visual home here. This asserts the factory tolerates them (no
/// crash, no unexpected UIRefreshControl mutation) whether they arrive as a
/// single `"style"` dict (the generic `updateProp` path) or pre-flattened
/// into individual keys (the `updateStyle` op's path -- see
/// `NativeBridge.handleUpdateStyle`).
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

        // The wrapper stays hidden/zero-sized -- style has no visual effect
        // on this placeholder view, only recognized props (refreshing/
        // tintColor/title) do.
        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(view.frame, .zero)
    }

    func testUpdatePropWithFlattenedStyleKeysDoesNotCrash() {
        // Mirrors how `NativeBridge.handleUpdateStyle` actually delivers a
        // style object: one `updateProp` call per key.
        let factory = VRefreshControlFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "backgroundColor", value: "#ff0000")
        factory.updateProp(view: view, key: "padding", value: 8)
        factory.updateProp(view: view, key: "opacity", value: 0.5)

        XCTAssertTrue(view.isHidden)
    }

    func testRecognizedPropsStillWorkAlongsideUnknownStyleKeys() {
        let factory = VRefreshControlFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "backgroundColor", value: "#ff0000")
        factory.updateProp(view: view, key: "tintColor", value: "#00ff00")

        let refreshControl = VRefreshControlFactory.refreshControl(for: view)
        XCTAssertNotNil(refreshControl)
        XCTAssertEqual(refreshControl?.tintColor, UIColor.fromHex("#00ff00"))
    }
}
#endif
