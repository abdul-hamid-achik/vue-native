#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Tests for VImageFactory, focused on the bundled-asset (`source.asset`) code
/// path. The asset *success* path loads via `UIImage(named:)`, which resolves
/// against the main bundle / Asset Catalog and therefore cannot be exercised in
/// an SPM unit-test bundle (test resources live in `Bundle.module`, not the main
/// bundle). The missing-asset error path, asset-over-uri precedence, and source
/// clearing are all deterministic and covered here.
@MainActor
final class VImageFactoryTests: XCTestCase {

    private var factory: VImageFactory!

    override func setUp() {
        super.setUp()
        factory = VImageFactory()
    }

    override func tearDown() {
        factory = nil
        super.tearDown()
    }

    // MARK: - Creation

    func testCreateViewReturnsImageView() {
        let view = factory.createView()
        XCTAssertTrue(view is UIImageView, "VImageFactory should create a UIImageView")
    }

    // MARK: - Asset loading

    func testMissingAssetFiresErrorEvent() {
        let imageView = factory.createView()
        var errorPayload: Any? = "not_called"
        var loadFired = false
        factory.addEventListener(view: imageView, event: "error") { payload in errorPayload = payload }
        factory.addEventListener(view: imageView, event: "load") { _ in loadFired = true }

        factory.updateProp(
            view: imageView,
            key: "source",
            value: ["asset": "definitely_not_a_real_asset_xyz"]
        )

        XCTAssertFalse(loadFired, "load must not fire for a missing asset")
        let message = (errorPayload as? [String: Any])?["message"] as? String
        XCTAssertNotNil(message, "error event should fire with a message payload")
        XCTAssertTrue(message?.contains("Asset not found") == true)
        XCTAssertNil((imageView as? UIImageView)?.image, "no image should be set for a missing asset")
    }

    func testAssetTakesPrecedenceOverURI() {
        // When both asset and uri are present, the asset path is chosen. A missing
        // asset therefore fires error synchronously WITHOUT any network request,
        // proving the asset branch wins over the (async) uri branch.
        let imageView = factory.createView()
        var errorPayload: Any? = nil
        factory.addEventListener(view: imageView, event: "error") { payload in errorPayload = payload }

        factory.updateProp(
            view: imageView,
            key: "source",
            value: [
                "asset": "definitely_not_a_real_asset_xyz",
                "uri": "https://example.com/never-fetched.png",
            ]
        )

        let message = (errorPayload as? [String: Any])?["message"] as? String
        XCTAssertTrue(message?.contains("Asset not found") == true, "asset branch should be taken first")
    }

    // MARK: - Source clearing

    func testNilSourceClearsImage() {
        guard let imageView = factory.createView() as? UIImageView else {
            return XCTFail("Expected a UIImageView")
        }
        imageView.image = UIImage()
        factory.updateProp(view: imageView, key: "source", value: nil)
        XCTAssertNil(imageView.image, "nil source should clear the image")
    }

    func testEmptyURISourceClearsImage() {
        guard let imageView = factory.createView() as? UIImageView else {
            return XCTFail("Expected a UIImageView")
        }
        imageView.image = UIImage()
        factory.updateProp(view: imageView, key: "source", value: ["uri": ""])
        XCTAssertNil(imageView.image, "empty uri with no asset should clear the image")
    }

    // MARK: - Resize mode

    func testResizeModeMapsContentMode() {
        guard let imageView = factory.createView() as? UIImageView else {
            return XCTFail("Expected a UIImageView")
        }
        factory.updateProp(view: imageView, key: "resizeMode", value: "contain")
        XCTAssertEqual(imageView.contentMode, .scaleAspectFit)
        factory.updateProp(view: imageView, key: "resizeMode", value: "stretch")
        XCTAssertEqual(imageView.contentMode, .scaleToFill)
        factory.updateProp(view: imageView, key: "resizeMode", value: "center")
        XCTAssertEqual(imageView.contentMode, .center)
    }
}
#endif
