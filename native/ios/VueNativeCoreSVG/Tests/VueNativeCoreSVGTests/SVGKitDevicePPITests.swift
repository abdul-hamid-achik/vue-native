#if canImport(UIKit)
import XCTest
import UIKit
import SVGKit
@testable import VueNativeCore
@testable import VueNativeCoreSVG
import VueNativeCoreSVGCompat

/// A tinted, stroked icon (Lucide style) is the case that crashed Debug apps on Apple Silicon
/// simulators: `stroke-width` resolves an `SVGLength`, whose class initializer asserted on the
/// unknown `arm64` model. `register()` primes SVGKit so this renders instead.
@MainActor
final class SVGKitDevicePPITests: XCTestCase {
    private let strokedIcon = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="2"><path d="M20 6 9 17l-5-5"/></svg>
    """

    func testStrokedTintedIconRendersAfterRegister() {
        VueNativeCoreSVG.register()
        VNPrimeSVGKitDevicePPI() // idempotent
        let factory = VSVGFactory()
        let view = factory.createView()
        var errorFired = false
        factory.addEventListener(view: view, event: "error") { _ in errorFired = true }
        factory.updateProp(view: view, key: "source", value: ["svg": strokedIcon])
        factory.updateProp(view: view, key: "tintColor", value: "#0f766e")
        XCTAssertFalse(errorFired)
    }
}
#endif
