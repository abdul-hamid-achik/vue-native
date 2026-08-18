#if canImport(UIKit)
import XCTest
import UIKit
import AVFoundation
@testable import VueNativeCore

@MainActor
final class CameraModuleTests: XCTestCase {
    func testDestroyStopsQRScanIdempotently() {
        let module = CameraModule(bridge: NativeBridge.shared)
        module.destroy()
        module.destroy()
    }

    func testStopQRScanWithoutStartingIsSafe() {
        let module = CameraModule(bridge: NativeBridge.shared)
        module.invoke(method: "stopQRScan", args: []) { result, error in
            XCTAssertNil(error)
            XCTAssertNil(result)
        }
        module.destroy()
    }

    func testQRScannerViewControllerBuildsACloseControl() {
        let session = AVCaptureSession()
        let scanner = QRScannerViewController(session: session)
        scanner.loadViewIfNeeded()
        XCTAssertEqual(scanner.view.backgroundColor, .black)
        XCTAssertTrue(scanner.view.subviews.contains { $0 is UIButton })
    }
}
#endif
