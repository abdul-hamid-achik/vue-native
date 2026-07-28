import AppKit
import XCTest
@testable import VueNativeMacOS

@MainActor
final class VSVGFactoryTests: XCTestCase {

    /// A minimal but well-formed SVG with an explicit viewBox + width/height so
    /// SVGKit reports a concrete intrinsic size.
    private let validSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">\
    <rect x="0" y="0" width="24" height="24" fill="#ff0000"/>\
    <circle cx="12" cy="12" r="6" fill="#0000ff"/>\
    </svg>
    """

    func testValidInlineSVGRenderImageAndFiresLoad() throws {
        let factory = VSVGFactory()
        let view = try XCTUnwrap(factory.createView() as? VSVGView)

        var loadPayload: [String: Any]?
        var errorCount = 0
        factory.addEventListener(view: view, event: "load") { payload in
            loadPayload = payload as? [String: Any]
        }
        factory.addEventListener(view: view, event: "error") { _ in errorCount += 1 }

        factory.updateProp(view: view, key: "source", value: ["svg": validSVG])

        let image = try XCTUnwrap(
            view.imageView.image,
            "Expected a rendered NSImage for a valid inline SVG"
        )
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)

        let payload = try XCTUnwrap(loadPayload, "Expected the load event to fire")
        XCTAssertGreaterThan(payload["width"] as? CGFloat ?? 0, 0)
        XCTAssertGreaterThan(payload["height"] as? CGFloat ?? 0, 0)
        XCTAssertEqual(errorCount, 0, "Valid SVG must not fire an error event")
    }

    func testInvalidSVGFIresErrorAndDoesNotRender() throws {
        let factory = VSVGFactory()
        let view = try XCTUnwrap(factory.createView() as? VSVGView)

        var errorPayload: [String: Any]?
        var loadCount = 0
        factory.addEventListener(view: view, event: "error") { payload in
            errorPayload = payload as? [String: Any]
        }
        factory.addEventListener(view: view, event: "load") { _ in loadCount += 1 }

        // Must not crash on garbage input.
        factory.updateProp(view: view, key: "source", value: ["svg": "this is not svg <<< >>>"])

        XCTAssertNil(view.imageView.image, "Invalid SVG must not produce an image")
        let payload = try XCTUnwrap(errorPayload, "Expected the error event to fire")
        XCTAssertFalse((payload["message"] as? String)?.isEmpty ?? true)
        XCTAssertEqual(loadCount, 0, "Invalid SVG must not fire a load event")
    }

    func testEmptySourceClearsImageWithoutEvents() throws {
        let factory = VSVGFactory()
        let view = try XCTUnwrap(factory.createView() as? VSVGView)

        var loadCount = 0
        var errorCount = 0
        factory.addEventListener(view: view, event: "load") { _ in loadCount += 1 }
        factory.addEventListener(view: view, event: "error") { _ in errorCount += 1 }

        factory.updateProp(view: view, key: "source", value: ["svg": validSVG])
        XCTAssertNotNil(view.imageView.image)

        // A source dict with no recognized field clears the image.
        factory.updateProp(view: view, key: "source", value: ["unknown": "x"])
        XCTAssertNil(view.imageView.image)
        XCTAssertEqual(errorCount, 0, "Clearing the source is not an error condition")
        XCTAssertEqual(loadCount, 1, "Only the initial valid render should fire load")
    }

    func testTintColorAppliesWithoutCrash() throws {
        let factory = VSVGFactory()
        let view = try XCTUnwrap(factory.createView() as? VSVGView)

        factory.updateProp(view: view, key: "source", value: ["svg": validSVG])
        XCTAssertNotNil(view.imageView.image)

        factory.updateProp(view: view, key: "tintColor", value: "#00ff00")
        XCTAssertNotNil(view.imageView.contentTintColor, "Tint color should be applied")
        XCTAssertEqual(view.imageView.image?.isTemplate, true, "Image should be a template for tinting")

        // Clearing the tint should also be safe.
        factory.updateProp(view: view, key: "tintColor", value: nil)
        XCTAssertNil(view.imageView.contentTintColor)
    }

    func testTintColorBeforeSourceDoesNotCrash() throws {
        let factory = VSVGFactory()
        let view = try XCTUnwrap(factory.createView() as? VSVGView)

        // Tint set before any source — no image yet, must not crash.
        factory.updateProp(view: view, key: "tintColor", value: "#0000ff")
        XCTAssertNil(view.imageView.image)

        // A later render should pick up the stored tint.
        factory.updateProp(view: view, key: "source", value: ["svg": validSVG])
        XCTAssertNotNil(view.imageView.image)
        XCTAssertNotNil(view.imageView.contentTintColor)
        XCTAssertEqual(view.imageView.image?.isTemplate, true)
    }

    func testRemoveEventListenerStopsLoadCallbacks() throws {
        let factory = VSVGFactory()
        let view = try XCTUnwrap(factory.createView() as? VSVGView)

        var loadCount = 0
        factory.addEventListener(view: view, event: "load") { _ in loadCount += 1 }
        factory.removeEventListener(view: view, event: "load")

        factory.updateProp(view: view, key: "source", value: ["svg": validSVG])
        XCTAssertNotNil(view.imageView.image)
        XCTAssertEqual(loadCount, 0, "Removed listener must not be invoked")
    }
}
