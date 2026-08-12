#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Tests for the hot reload WebSocket URL construction on
/// ``VueNativeViewController``.
///
/// These exercise the pure ``VueNativeViewController/hotReloadURL(base:token:)``
/// helper directly, so they run without a simulator-driven view-controller
/// lifecycle and without touching the shared JS runtime / bridge singletons.
@MainActor
final class VueNativeViewControllerHotReloadTests: XCTestCase {

    func testAppendsTokenQueryItem() {
        let base = URL(string: "ws://localhost:8174")!
        let result = VueNativeViewController.hotReloadURL(base: base, token: "deadbeef01")

        XCTAssertEqual(result.absoluteString, "ws://localhost:8174?token=deadbeef01")
    }

    func testReturnsBaseUnchangedWhenTokenIsEmpty() {
        let base = URL(string: "ws://localhost:8174")!
        let result = VueNativeViewController.hotReloadURL(base: base, token: "")

        XCTAssertEqual(result, base, "an empty token must leave the URL untouched")
        let queryItems = URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertTrue(queryItems == nil || queryItems?.isEmpty == true)
    }

    func testPreservesExistingQueryItems() {
        let base = URL(string: "ws://192.168.1.10:8174?foo=bar")!
        let result = VueNativeViewController.hotReloadURL(base: base, token: "abc123")

        let queryItems = URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "foo", value: "bar")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "token", value: "abc123")))
    }

    func testPreservesSchemeHostAndPort() {
        let base = URL(string: "ws://192.168.1.10:8174")!
        let result = VueNativeViewController.hotReloadURL(base: base, token: "abc123")

        let components = URLComponents(url: result, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.scheme, "ws")
        XCTAssertEqual(components?.host, "192.168.1.10")
        XCTAssertEqual(components?.port, 8174)
    }

    // MARK: - Missing embedded bundle overlay

    /// Regression test: a missing embedded bundle used to only NSLog and
    /// leave a silent black screen (Android shows an error overlay for the
    /// same case). With no dev server to fall back to, the overlay must show.
    func testShowsOverlayWhenBundleMissingAndNoDevServer() {
        XCTAssertTrue(
            VueNativeViewController.shouldShowMissingBundleOverlay(loadSucceeded: false, devServerURL: nil),
            "a failed embedded load with no dev server configured has no fallback and must surface the overlay"
        )
    }

    /// When a dev server is configured, the embedded bundle is only used to
    /// seed the hot-reload token; `loadBundle()` still connects to the dev
    /// server afterward, so a missing embedded bundle there is not fatal.
    func testSuppressesOverlayWhenBundleMissingButDevServerConfigured() {
        XCTAssertFalse(
            VueNativeViewController.shouldShowMissingBundleOverlay(
                loadSucceeded: false,
                devServerURL: URL(string: "ws://localhost:8174")
            ),
            "a dev server fallback is still available, so the overlay should not show"
        )
    }

    func testSuppressesOverlayOnSuccessfulLoad() {
        XCTAssertFalse(
            VueNativeViewController.shouldShowMissingBundleOverlay(loadSucceeded: true, devServerURL: nil),
            "a successful load should never show the missing-bundle overlay"
        )
    }
}
#endif
