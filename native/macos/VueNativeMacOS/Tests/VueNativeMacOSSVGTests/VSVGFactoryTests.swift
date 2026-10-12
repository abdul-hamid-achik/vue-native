import AppKit
import VueNativeShared
import XCTest
@testable import VueNativeMacOS
@testable import VueNativeMacOSSVG

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

    func testTintColorSetBeforeSourceIsRetainedAndAppliedToTheRender() throws {
        let factory = VSVGFactory()
        let view = try XCTUnwrap(factory.createView() as? VSVGView)
        let tint = NSColor.fromHex("#0000ff")
        XCTAssertNotNil(tint, "precondition: the tint hex must parse")

        // Tint set before any source — no image yet, must not crash.
        factory.updateProp(view: view, key: "tintColor", value: "#0000ff")
        XCTAssertNil(view.imageView.image)
        // The factory stores the parsed color on the view (associated object)
        // *and* pushes it to the image view immediately, so a later render can
        // pick it back up. Without that storage the tint would be silently lost
        // for any component whose props arrive tint-before-source.
        XCTAssertEqual(
            view.imageView.contentTintColor, tint,
            "a tint set before any source must be retained on the image view"
        )

        // A later render should pick up the stored tint.
        factory.updateProp(view: view, key: "source", value: ["svg": validSVG])
        XCTAssertNotNil(view.imageView.image)
        XCTAssertNotNil(view.imageView.contentTintColor)
        XCTAssertEqual(
            view.imageView.contentTintColor, tint,
            "the render must apply the tint that was set before the source arrived"
        )
        XCTAssertEqual(view.imageView.image?.isTemplate, true)

        // Control: rendering a second source keeps re-applying the stored tint,
        // i.e. it survives on the view and not just on the first image.
        factory.updateProp(view: view, key: "source", value: ["svg": validSVG])
        XCTAssertEqual(view.imageView.contentTintColor, tint)
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

    // MARK: - B4-6 local files are confined to the sandbox

    /// A valid SVG written beside the test bundle. That directory is outside
    /// every sandbox root, so a load from it must be refused.
    private func writeSVGOutsideSandbox() throws -> URL {
        let directory = Bundle(for: VSVGFactoryTests.self).bundleURL.deletingLastPathComponent()
        let url = directory.appendingPathComponent("vsvg-outside-\(UUID().uuidString).svg")
        try validSVG.write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testSchemelessAndFileURIOutsideTheSandboxFireErrorWithoutRendering() throws {
        let outside = try writeSVGOutsideSandbox()
        for uri in [outside.path, outside.absoluteString] {
            let factory = VSVGFactory()
            let view = try XCTUnwrap(factory.createView() as? VSVGView)
            var errorCount = 0
            var loadCount = 0
            factory.addEventListener(view: view, event: "error") { _ in errorCount += 1 }
            factory.addEventListener(view: view, event: "load") { _ in loadCount += 1 }

            factory.updateProp(view: view, key: "source", value: ["uri": uri])

            XCTAssertNil(view.imageView.image, "\(uri) must not be rendered")
            XCTAssertEqual(errorCount, 1, "\(uri) must fire the error event")
            XCTAssertEqual(loadCount, 0)
        }
    }

    func testLocalFileInsideTheSandboxStillRenders() throws {
        // The sandbox's own temporary root is an allowed location, unlike the
        // system temp directory it lives in.
        let root = try XCTUnwrap(FileSystemSandbox.shared.allowedRoots().last)
        let url = root.appendingPathComponent("vsvg-inside-\(UUID().uuidString).svg")
        try validSVG.write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }

        let factory = VSVGFactory()
        let view = try XCTUnwrap(factory.createView() as? VSVGView)
        var loadCount = 0
        factory.addEventListener(view: view, event: "load") { _ in loadCount += 1 }

        factory.updateProp(view: view, key: "source", value: ["uri": url.path])

        XCTAssertNotNil(view.imageView.image, "a sandboxed local file must still render")
        XCTAssertEqual(loadCount, 1)
    }

    // MARK: - B4-1 remote loads use the certificate-pinned session

    func testRemoteLoadsResolveTheCertificatePinnedSession() {
        let pin = "sha256/" + Data(repeating: 7, count: 32).base64EncodedString()
        CertificatePinning.shared.configurePins(["svg-pinned.invalid": [pin]])
        defer { CertificatePinning.shared.clearPins() }
        XCTAssertTrue(CertificatePinning.shared.hasPins(for: "svg-pinned.invalid"))

        let factory = VSVGFactory()

        // The shared session bypasses pinning. The factory must resolve the
        // pinned session per request, as VImageFactory does.
        XCTAssertTrue(factory.urlSession === CertificatePinning.shared.requestSession)
        XCTAssertFalse(factory.urlSession === URLSession.shared)
    }
}
