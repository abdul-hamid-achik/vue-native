#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Tests for the ImagePicker module contract.
///
/// The live `PHPickerViewController` presentation is intentionally NOT exercised
/// here (it requires a presented UI and user interaction). These tests cover the
/// module's routing contract, its cancellation behaviour, and the temporary-file
/// encoding helper deterministically.
@MainActor
final class ImagePickerModuleTests: XCTestCase {

    // MARK: - Module contract

    func testModuleName() {
        XCTAssertEqual(ImagePickerModule().moduleName, "ImagePicker")
    }

    func testUnknownMethodReturnsError() {
        let completed = expectation(description: "unknown method")
        var capturedError: String?
        ImagePickerModule().invoke(method: "doesNotExist", args: []) { _, error in
            capturedError = error
            completed.fulfill()
        }
        wait(for: [completed], timeout: 2)

        XCTAssertNotNil(capturedError)
        XCTAssertTrue(capturedError?.contains("Unknown method") ?? false)
    }

    // MARK: - Cancellation contract

    func testEmptyPickerResultsResolveToNullWithoutError() {
        // An empty results array is how PHPickerViewController reports a cancel.
        // The documented contract is: resolve with null (nil) and NO error.
        var didCallback = false
        var capturedResult: Any? = "sentinel"
        var capturedError: String? = "sentinel"

        ImagePickerModule.processPickerResults([]) { result, error in
            didCallback = true
            capturedResult = result
            capturedError = error
        }

        XCTAssertTrue(didCallback, "Cancellation should resolve the callback synchronously")
        XCTAssertNil(capturedResult, "Cancellation should yield a null result")
        XCTAssertNil(capturedError, "Cancellation must not be reported as an error")
    }

    // MARK: - Temporary file encoding

    func testWriteTemporaryJPEGCreatesReadableFile() {
        let image = makeImage(width: 12, height: 34)

        guard let url = ImagePickerModule.writeTemporaryJPEG(image) else {
            return XCTFail("writeTemporaryJPEG should return a file URL")
        }
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.pathExtension, "jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let reloaded = UIImage(contentsOfFile: url.path)
        XCTAssertNotNil(reloaded, "The written JPEG should be readable back as a UIImage")
        XCTAssertEqual(Int(reloaded?.size.width ?? 0), 12)
        XCTAssertEqual(Int(reloaded?.size.height ?? 0), 34)
    }

    // MARK: - Helpers

    private func makeImage(width: Int, height: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
#endif
