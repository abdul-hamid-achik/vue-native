#if canImport(UIKit)
import XCTest
import UIKit
import SVGKit
@testable import VueNativeCore

/// Tests for VSVGFactory.
///
/// The inline (`source.svg`) and missing-asset (`source.asset`) paths are fully
/// deterministic and covered here. The remote (`source.uri`) path performs a
/// real network fetch on a background queue, so it is intentionally not
/// exercised in unit tests (it would be flaky and slow).
@MainActor
final class VSVGFactoryTests: XCTestCase {

    private var factory: VSVGFactory!

    /// A minimal but valid SVG: explicit size + a single filled rect, so the
    /// parser produces a DOM tree and at least one filled CAShapeLayer.
    private let validSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
      <rect x="0" y="0" width="100" height="100" fill="#FF0000"/>
    </svg>
    """

    /// Malformed XML (truncated element) — guaranteed to fail parsing.
    private let invalidSVG = "<svg><rect width=\"100\" height=\"100\""

    override func setUp() {
        super.setUp()
        factory = VSVGFactory()

        // Warm up SVGKit. On the iPad (A16) simulator, SVGKit's
        // +[SVGLength pixelsPerInchForCurrentDevice] trips an NSAssert for
        // device models newer than its hardcoded list, and the FIRST sized
        // parse in the process can return nil. Parsing once here (ignoring the
        // result) absorbs that one-time quirk so the deterministic assertions
        // below run against an already-initialized parser.
        if let warmupSource = SVGKSourceString.source(fromContentsOf: validSVG) {
            _ = SVGKImage(source: warmupSource)
        }
    }

    override func tearDown() {
        factory = nil
        super.tearDown()
    }

    // MARK: - Creation

    func testCreateViewReturnsSVGImageView() {
        let view = factory.createView()
        XCTAssertTrue(view is SVGKFastImageView, "VSVGFactory should create an SVGKFastImageView")
    }

    // MARK: - Inline SVG

    func testValidInlineSVGRenderAndFiresLoad() {
        let view = factory.createView()
        var loadPayload: Any? = "not_called"
        var errorFired = false
        factory.addEventListener(view: view, event: "load") { payload in loadPayload = payload }
        factory.addEventListener(view: view, event: "error") { _ in errorFired = true }

        factory.updateProp(view: view, key: "source", value: ["svg": validSVG])

        XCTAssertFalse(errorFired, "error must not fire for a valid inline SVG")
        XCTAssertNotNil(loadPayload as? [String: Any], "load should fire with a dictionary payload")

        guard let svgView = view as? SVGKFastImageView else {
            return XCTFail("Expected an SVGKFastImageView")
        }
        XCTAssertNotNil(svgView.image, "a parsed SVGKImage should be installed")
        XCTAssertNotNil(svgView.image?.domTree, "the SVG DOM tree should be parsed")
        XCTAssertNotNil(svgView.image?.caLayerTree, "the SVG layer tree should be built")

        // The rendered content must not be empty: a filled rect yields at least
        // one CAShapeLayer in the layer tree.
        let shapes = collectShapeLayers(in: svgView.image?.caLayerTree)
        XCTAssertFalse(shapes.isEmpty, "a valid SVG with a rect should produce shape layers")
    }

    func testInvalidInlineSVGFIresError() {
        let view = factory.createView()
        var errorPayload: Any? = "not_called"
        var loadFired = false
        factory.addEventListener(view: view, event: "error") { payload in errorPayload = payload }
        factory.addEventListener(view: view, event: "load") { _ in loadFired = true }

        factory.updateProp(view: view, key: "source", value: ["svg": invalidSVG])

        XCTAssertFalse(loadFired, "load must not fire for an invalid SVG")
        let message = (errorPayload as? [String: Any])?["message"] as? String
        XCTAssertNotNil(message, "error event should fire with a message payload")
        XCTAssertTrue(message?.contains("Failed to parse inline SVG") == true)
    }

    func testInlineSVGTakesPrecedenceOverMissingAsset() {
        // When both svg and asset are present, the inline svg branch wins. A
        // valid svg therefore fires load WITHOUT any error, proving the svg
        // branch is taken before the (missing) asset branch.
        let view = factory.createView()
        var loadFired = false
        var errorFired = false
        factory.addEventListener(view: view, event: "load") { _ in loadFired = true }
        factory.addEventListener(view: view, event: "error") { _ in errorFired = true }

        factory.updateProp(
            view: view,
            key: "source",
            value: [
                "svg": validSVG,
                "asset": "definitely_not_a_real_svg_asset_xyz",
            ]
        )

        XCTAssertTrue(loadFired, "inline svg branch should render and fire load")
        XCTAssertFalse(errorFired, "the missing asset should never be reached")
    }

    // MARK: - Asset loading

    func testMissingAssetFiresError() {
        let view = factory.createView()
        var errorPayload: Any? = "not_called"
        var loadFired = false
        factory.addEventListener(view: view, event: "error") { payload in errorPayload = payload }
        factory.addEventListener(view: view, event: "load") { _ in loadFired = true }

        factory.updateProp(
            view: view,
            key: "source",
            value: ["asset": "definitely_not_a_real_svg_asset_xyz"]
        )

        XCTAssertFalse(loadFired, "load must not fire for a missing asset")
        let message = (errorPayload as? [String: Any])?["message"] as? String
        XCTAssertTrue(message?.contains("Asset not found") == true)
    }

    // MARK: - Source clearing

    func testNilSourceClearsRenderedSVG() {
        guard let svgView = factory.createView() as? SVGKFastImageView else {
            return XCTFail("Expected an SVGKFastImageView")
        }
        factory.updateProp(view: svgView, key: "source", value: ["svg": validSVG])
        XCTAssertNotNil(svgView.image?.domTree, "precondition: a valid SVG renders a DOM tree")

        factory.updateProp(view: svgView, key: "source", value: nil)
        XCTAssertNil(svgView.image?.domTree, "nil source should reset the image to an empty SVGKImage")
    }

    // MARK: - Tint color

    func testTintColorAppliesWithoutCrash() {
        let view = factory.createView()
        var loadCount = 0
        factory.addEventListener(view: view, event: "load") { _ in loadCount += 1 }
        factory.updateProp(view: view, key: "source", value: ["svg": validSVG])
        XCTAssertEqual(loadCount, 1, "precondition: the valid SVG fires load once")

        guard let svgView = view as? SVGKFastImageView else {
            return XCTFail("Expected an SVGKFastImageView")
        }

        // Capture the original fill of the first filled shape layer so we can
        // prove the tint actually recolored it.
        let shapes = collectShapeLayers(in: svgView.image?.caLayerTree)
        let tintedShape = shapes.first(where: { $0.fillColor != nil })
        let originalFill = tintedShape?.fillColor

        // Applying a tint must not crash and must keep the rendered image.
        factory.updateProp(view: view, key: "tintColor", value: "#00FF00")
        XCTAssertNotNil(svgView.image, "image should remain set after tinting")
        XCTAssertEqual(loadCount, 1, "tintColor alone should not re-fire load")

        if let tintedShape, let originalFill {
            XCTAssertNotEqual(
                tintedShape.fillColor,
                originalFill,
                "tintColor should recolor the filled shape layer"
            )
        }
    }

    func testInvalidTintColorIsIgnoredWithoutCrash() {
        let view = factory.createView()
        factory.updateProp(view: view, key: "source", value: ["svg": validSVG])
        guard let svgView = view as? SVGKFastImageView else {
            return XCTFail("Expected an SVGKFastImageView")
        }
        let before = svgView.image

        // An unparseable color string is a no-op (no crash, image untouched).
        factory.updateProp(view: view, key: "tintColor", value: "not-a-color")
        XCTAssertTrue(svgView.image === before, "invalid tint should leave the image unchanged")
    }

    // MARK: - Helpers

    /// Recursively collect every CAShapeLayer in a layer tree.
    private func collectShapeLayers(in layer: CALayer?) -> [CAShapeLayer] {
        guard let layer else { return [] }
        var result: [CAShapeLayer] = []
        if let shape = layer as? CAShapeLayer {
            result.append(shape)
        }
        for sublayer in layer.sublayers ?? [] {
            result.append(contentsOf: collectShapeLayers(in: sublayer))
        }
        return result
    }
}
#endif
