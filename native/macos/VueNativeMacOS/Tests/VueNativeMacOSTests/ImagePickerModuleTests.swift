import AppKit
import XCTest
import VueNativeShared
@testable import VueNativeMacOS

/// Tests for the `ImagePicker` native module (`pickImage`).
///
/// The modal `NSOpenPanel` is never presented in tests: the module's presenter
/// is injected so the result/cancel contract and the dimension parsing can be
/// exercised deterministically.
@MainActor
final class ImagePickerModuleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Some shared modules dereference NSApp; keep the test host deterministic.
        _ = NSApplication.shared
    }

    // MARK: - Helpers

    private func invoke(
        _ module: ImagePickerModule,
        method: String,
        args: [Any]
    ) async -> (result: Any?, error: String?) {
        final class Box {
            var result: Any?
            var error: String? = "not_called"
        }
        let box = Box()
        let exp = expectation(description: "ImagePicker.\(method)")
        module.invoke(method: method, args: args) { result, error in
            box.result = result
            box.error = error
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 3)
        return (box.result, box.error)
    }

    /// Write a real PNG of the given pixel size to a temp file and return its URL.
    private func makeTestImageURL(width: Int, height: Int) -> URL? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let data = rep.representation(using: .png, properties: [:]) else {
            return nil
        }

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vn-imagepicker-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Contract

    func testModuleNameAndPickImageRecognized() async {
        let module = ImagePickerModule(presentPanel: { completion in completion(nil) })
        XCTAssertEqual(module.moduleName, "ImagePicker")

        // pickImage with an options dict (as the JS composable sends) is recognized.
        let (result, error) = await invoke(module, method: "pickImage", args: [["mediaType": "photo"]])
        XCTAssertNil(error)
        XCTAssertNil(result) // injected presenter cancels
    }

    func testPickImageCancellationReturnsNull() async {
        let module = ImagePickerModule(presentPanel: { completion in completion(nil) })
        let (result, error) = await invoke(module, method: "pickImage", args: [])
        XCTAssertNil(error)
        XCTAssertNil(result)
    }

    func testPickImageReturnsURIAndDimensions() async {
        guard let url = makeTestImageURL(width: 24, height: 16) else {
            return XCTFail("could not create test image")
        }
        defer { try? FileManager.default.removeItem(at: url) }

        let module = ImagePickerModule(presentPanel: { completion in completion(url) })
        let (result, error) = await invoke(module, method: "pickImage", args: [[:]])
        XCTAssertNil(error)

        guard let picked = result as? [String: Any] else {
            return XCTFail("expected a dictionary result, got \(String(describing: result))")
        }

        let uri = picked["uri"] as? String
        XCTAssertNotNil(uri)
        XCTAssertTrue(uri?.hasPrefix("file://") == true, "uri should be a file:// URL, got \(uri ?? "nil")")
        XCTAssertEqual(picked["width"] as? Int, 24)
        XCTAssertEqual(picked["height"] as? Int, 16)
    }

    // MARK: - Dimension parsing

    func testImageDimensionsParsing() {
        guard let url = makeTestImageURL(width: 40, height: 30) else {
            return XCTFail("could not create test image")
        }
        defer { try? FileManager.default.removeItem(at: url) }

        let dims = ImagePickerModule.imageDimensions(at: url)
        XCTAssertEqual(dims?.width, 40)
        XCTAssertEqual(dims?.height, 30)
    }

    func testImageDimensionsForMissingFileIsNil() {
        let missing = URL(fileURLWithPath: "/tmp/vn-definitely-not-here-\(UUID().uuidString).png")
        XCTAssertNil(ImagePickerModule.imageDimensions(at: missing))
    }

    func testRejectsUnknownMethod() async {
        let module = ImagePickerModule(presentPanel: { completion in completion(nil) })
        let (_, error) = await invoke(module, method: "definitelyNotAMethod", args: [])
        XCTAssertTrue(error?.contains("Unknown method") == true)
    }
}
