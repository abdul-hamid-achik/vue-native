import AppKit
import XCTest
@testable import VueNativeMacOS

/// Core-side half of the optional-component seam.
///
/// `<VSVG>` moved to the `VueNativeMacOSSVG` product so an app that never
/// renders an SVG does not resolve SVGKit. This target deliberately does not
/// depend on that product (that is what keeps the split honest), so it can only
/// assert the core-side facts: the tag is not a built-in, and an unregistered
/// optional tag produces a diagnostic that names the missing product and the
/// call that fixes it. `VueNativeMacOSSVGTests` covers the other half — that
/// `VueNativeMacOSSVG.register()` puts the factory back.
@MainActor
final class OptionalComponentRegistrationTests: XCTestCase {

    func testVSVGIsNotRegisteredByCoreDefaults() {
        XCTAssertNil(
            ComponentRegistry.shared.factory(for: "VSVG"),
            "VueNativeMacOS must not register <VSVG>; it is provided by the VueNativeMacOSSVG product"
        )
        XCTAssertNil(
            ComponentRegistry.shared.createView(type: "VSVG"),
            "createView must return nil for <VSVG> in a core-only build"
        )
    }

    func testVSVGIsDeclaredAsAnOptionalComponent() {
        // A tag that is neither built in nor declared optional would fall through
        // to the generic "no factory registered" warning, which does not tell the
        // developer that a product exists. The hint table is what makes the
        // failure actionable.
        let hint = ComponentRegistry.optionalComponentHints["VSVG"]
        XCTAssertNotNil(hint, "<VSVG> must be listed as an optional component")
        XCTAssertTrue(hint?.contains("VueNativeMacOSSVG") == true, "the hint should name the product")
        XCTAssertTrue(hint?.contains("register()") == true, "the hint should name the call")
    }

    func testUnregisteredOptionalComponentDiagnosticNamesTheProductAndTheCall() {
        // createView returning nil is not a crash, so an app that linked nothing
        // and rendered `<VSVG>` would otherwise get an invisible gap in the
        // window with nothing actionable in the log.
        let message = ComponentRegistry.unknownComponentMessage(for: "VSVG", registered: [])

        XCTAssertTrue(message.contains("VueNativeMacOSSVG"), "the message should name the product")
        XCTAssertTrue(message.contains("register()"), "the message should name the call")
    }
}
