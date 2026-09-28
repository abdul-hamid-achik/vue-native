import AppKit
import XCTest
@testable import VueNativeMacOS
@testable import VueNativeMacOSSVG

/// Tests for the `<VSVG>` registration seam.
///
/// These live in the SVG test target on purpose: it is the only place that can
/// see both halves — `VueNativeMacOS`'s registry and the `VueNativeMacOSSVG`
/// bootstrap — which is exactly what the split has to guarantee. The core test
/// target cannot import SVGKit, so it asserts only the core-side facts (the tag
/// is *not* a built-in, and the diagnostic names this product).
///
/// `ComponentRegistry.shared` is a process-wide singleton shared with every
/// other test in this bundle, so each test restores the registry to the
/// core-only state it started from.
@MainActor
final class VueNativeMacOSSVGRegistrationTests: XCTestCase {

    override func tearDown() {
        // Leave the singleton as a core-only build would: `<VSVG>` unregistered.
        ComponentRegistry.shared.unregister("VSVG")
        super.tearDown()
    }

    // MARK: - Absent without the bootstrap, present with it

    func testVSVGIsUnregisteredUntilTheBootstrapRuns() {
        let registry = ComponentRegistry.shared

        // Core alone must not provide <VSVG> — that is the whole point of the
        // split. A factory here would mean the core target still links SVGKit.
        XCTAssertNil(
            registry.factory(for: "VSVG"),
            "<VSVG> must not be registered by VueNativeMacOS's defaults; it belongs to VueNativeMacOSSVG"
        )
        XCTAssertNil(
            registry.createView(type: "VSVG"),
            "createView must return nil for <VSVG> before VueNativeMacOSSVG.register()"
        )

        VueNativeMacOSSVG.register()

        XCTAssertNotNil(
            registry.factory(for: "VSVG"),
            "VueNativeMacOSSVG.register() must install the <VSVG> factory"
        )
        let view = registry.createView(type: "VSVG")
        XCTAssertNotNil(view, "createView must succeed once the bootstrap has run")
        XCTAssertTrue(
            view is VSVGView,
            "<VSVG> should create a VSVGView, got \(String(describing: view.map { type(of: $0) }))"
        )
        // A registered factory must also be reachable through the view, which is
        // how the bridge dispatches later prop updates and events.
        XCTAssertNotNil(
            view.flatMap { ComponentRegistry.factory(for: $0) },
            "the registry should attach the SVG factory to the view it created"
        )
    }

    // MARK: - Idempotence / late bootstrap

    func testRegisterIsIdempotent() {
        VueNativeMacOSSVG.register()
        let first = ComponentRegistry.shared.factory(for: "VSVG")
        VueNativeMacOSSVG.register()
        let second = ComponentRegistry.shared.factory(for: "VSVG")

        XCTAssertNotNil(first)
        XCTAssertNotNil(second, "a second register() must not drop the factory")
        XCTAssertNotNil(
            ComponentRegistry.shared.createView(type: "VSVG"),
            "<VSVG> must still render after a repeated register()"
        )
    }

    // MARK: - Loud, actionable failure when the product is missing

    func testUnregisteredVSVGDiagnosticNamesTheProductAndTheCall() {
        // The failure mode this guards is a silently blank view: createView
        // returns nil, nothing crashes, and the developer has no idea an
        // optional product is missing. The diagnostic has to name both the
        // product and the call that fixes it.
        let message = ComponentRegistry.unknownComponentMessage(for: "VSVG", registered: ["VView"])

        XCTAssertTrue(message.contains("VSVG"), "the diagnostic should name the component: \(message)")
        XCTAssertTrue(
            message.contains("VueNativeMacOSSVG"),
            "the diagnostic should name the missing product: \(message)"
        )
        XCTAssertTrue(
            message.contains("register()"),
            "the diagnostic should name the registration call: \(message)"
        )
    }

    func testNonOptionalUnknownComponentStillGetsTheOrdinaryDiagnostic() {
        // The optional-product message must not swallow ordinary typos.
        let message = ComponentRegistry.unknownComponentMessage(
            for: "VVieww",
            registered: ["VView", "VText"]
        )

        XCTAssertFalse(
            message.contains("VueNativeMacOSSVG"),
            "a mistyped built-in tag is not a missing optional product: \(message)"
        )
        XCTAssertTrue(
            message.contains("No factory registered"),
            "an unknown tag should still get the ordinary diagnostic: \(message)"
        )
        #if DEBUG
        // The registered-tag list is DEBUG-only.
        XCTAssertTrue(message.contains("VView"), "the diagnostic should list registered tags")
        #endif
    }
}
