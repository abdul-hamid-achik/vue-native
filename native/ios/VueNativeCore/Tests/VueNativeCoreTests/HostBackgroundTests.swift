#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// VN-14: the host view behind the safe area takes the app's outermost background.
@MainActor
final class HostBackgroundTests: XCTestCase {

    func testFindsTheAppBackgroundPastTransparentRootAndZeroSizeAnchors() {
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 760))
        let anchor = UIView(frame: .zero)
        anchor.backgroundColor = .clear
        let app = UIView(frame: root.bounds)
        app.backgroundColor = .systemTeal
        root.addSubview(anchor)
        root.addSubview(app)
        XCTAssertEqual(NativeBridge.appBackground(from: root), .systemTeal)
    }

    func testSkipsAnEmptyTransparentOverlayOfTheSameSize() {
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let app = UIView(frame: root.bounds)
        app.backgroundColor = UIColor(red: 0.06, green: 0.08, blue: 0.08, alpha: 1)
        let overlay = UIView(frame: root.bounds) // e.g. a teleport/dialog host, transparent
        overlay.backgroundColor = .clear
        root.addSubview(app)
        root.addSubview(overlay)
        XCTAssertEqual(NativeBridge.appBackground(from: root), app.backgroundColor)
        // Same with the overlay first.
        overlay.removeFromSuperview()
        root.insertSubview(overlay, at: 0)
        XCTAssertEqual(NativeBridge.appBackground(from: root), app.backgroundColor)
    }

    func testNoOpaqueBackgroundReturnsNil() {
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 760))
        root.addSubview(UIView(frame: root.bounds))
        XCTAssertNil(NativeBridge.appBackground(from: root))
    }
}
#endif
