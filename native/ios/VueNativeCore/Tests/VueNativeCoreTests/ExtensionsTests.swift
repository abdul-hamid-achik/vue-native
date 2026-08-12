#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Tests for `UIApplication.vn_keyWindow`'s selection logic.
///
/// `UIWindowScene.activationState` can't be set from test code (scenes are
/// created and driven by the system), so these exercise the pure
/// `vn_selectKeyWindow(from:)` helper with fabricated
/// `(activationState, keyWindow)` pairs instead of real scenes.
@MainActor
final class ExtensionsTests: XCTestCase {

    /// Regression test: `vn_keyWindow`'s doc comment promises "the first
    /// foreground-active window scene", but the old implementation just took
    /// the first connected scene with a key window, ignoring activationState
    /// entirely. A background/inactive scene listed before the active one
    /// must not win.
    func testSelectsForegroundActiveWindowOverEarlierInactiveOne() {
        let inactiveWindow = UIWindow(frame: .zero)
        let activeWindow = UIWindow(frame: .zero)

        let result = UIApplication.vn_selectKeyWindow(from: [
            (activationState: .background, keyWindow: inactiveWindow),
            (activationState: .foregroundActive, keyWindow: activeWindow),
        ])

        XCTAssertTrue(result === activeWindow, "the foreground-active scene's window should win even though it is listed second")
    }

    func testFallsBackToFirstKeyWindowWhenNoneAreForegroundActive() {
        let window = UIWindow(frame: .zero)

        let result = UIApplication.vn_selectKeyWindow(from: [
            (activationState: .foregroundInactive, keyWindow: window),
        ])

        XCTAssertTrue(result === window, "should fall back to the first available key window during scene transitions")
    }

    func testReturnsNilWhenNoScenesHaveAKeyWindow() {
        let result = UIApplication.vn_selectKeyWindow(from: [
            (activationState: .foregroundActive, keyWindow: nil),
            (activationState: .background, keyWindow: nil),
        ])

        XCTAssertNil(result)
    }
}
#endif
