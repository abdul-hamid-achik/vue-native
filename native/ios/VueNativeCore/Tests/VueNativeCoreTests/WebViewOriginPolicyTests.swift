#if canImport(UIKit)
import Foundation
import WebKit
import XCTest
@testable import VueNativeCore

/// Regression tests for P1-4: `VWebView` must not load arbitrary URIs and must
/// not forward `postMessage` payloads from origins the app did not declare.
///
/// `@MainActor` because the factory-wiring cases touch `VWebViewFactory`, which
/// is main-actor isolated.
@MainActor
final class WebViewOriginPolicyTests: XCTestCase {

    // MARK: - Scheme blocking

    func testDangerousSchemesAreBlockedEvenForAnExplicitSourceLoad() {
        let policy = WebViewOriginPolicy()
        for uri in [
            "javascript:alert(1)",
            "file:///etc/passwd",
            "data:text/html,<script>alert(1)</script>",
            "blob:https://example.com/uuid",
            "about:config",
        ] {
            let url = URL(string: uri)
            XCTAssertFalse(
                policy.isNavigationAllowed(url, isExplicitSourceLoad: true),
                "\(uri) must never be loadable, not even as the app's own source"
            )
            XCTAssertFalse(policy.isNavigationAllowed(url, isExplicitSourceLoad: false))
        }
        XCTAssertFalse(policy.isNavigationAllowed(nil, isExplicitSourceLoad: true))
    }

    // MARK: - Default deny

    func testDefaultsToDenyingEveryRemoteNavigation() {
        let policy = WebViewOriginPolicy()
        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "https://example.com/"), isExplicitSourceLoad: false))
        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "http://localhost:8080/"), isExplicitSourceLoad: false))
        XCTAssertFalse(policy.isMessageOriginAllowed(scheme: "https", host: "example.com", port: 0))
    }

    func testExplicitSourceIsAllowedAndSeedsTheAllowlist() {
        let policy = WebViewOriginPolicy()
        let source = URL(string: "https://app.example.com/page")
        // The factory allows the app's own declared source...
        XCTAssertTrue(policy.isNavigationAllowed(source, isExplicitSourceLoad: true))
        // ...but a redirect to the same origin is refused until it is recorded.
        XCTAssertFalse(policy.isNavigationAllowed(source, isExplicitSourceLoad: false))

        // This is what the factory does when applying the `source` prop.
        policy.recordSource(of: source!)
        XCTAssertTrue(policy.isNavigationAllowed(URL(string: "https://app.example.com/other"), isExplicitSourceLoad: false))
        XCTAssertTrue(policy.isMessageOriginAllowed(scheme: "https", host: "app.example.com", port: 0))
    }

    func testAllowlistingOneOriginDoesNotAllowAnother() {
        let policy = WebViewOriginPolicy()
        policy.recordSource(of: URL(string: "https://app.example.com/")!)

        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "https://evil.example.com/"), isExplicitSourceLoad: false))
        XCTAssertFalse(policy.isMessageOriginAllowed(scheme: "https", host: "evil.example.com", port: 0))
        // A different port is a different origin.
        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "https://app.example.com:8443/"), isExplicitSourceLoad: false))
        // So is a downgrade to plain http.
        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "http://app.example.com/"), isExplicitSourceLoad: false))
    }

    func testNonHttpSourceNeverWidensTheAllowlist() {
        let policy = WebViewOriginPolicy()
        policy.recordSource(of: URL(string: "file:///etc/passwd")!)
        XCTAssertTrue(policy.allowedOrigins.isEmpty)
    }

    // MARK: - Normalisation

    func testNormalisesSchemeHostCaseAndDefaultPorts() {
        XCTAssertEqual(WebViewOriginPolicy.origin(of: URL(string: "HTTPS://EXAMPLE.COM/path?q=1")), "https://example.com")
        XCTAssertEqual(WebViewOriginPolicy.origin(of: URL(string: "https://example.com:443/")), "https://example.com")
        XCTAssertEqual(WebViewOriginPolicy.origin(of: URL(string: "http://example.com:80/")), "http://example.com")
        XCTAssertEqual(WebViewOriginPolicy.origin(of: URL(string: "http://localhost:8080/x")), "http://localhost:8080")
        XCTAssertEqual(WebViewOriginPolicy.origin(of: URL(string: "about:blank")), WebViewOriginPolicy.aboutBlankOrigin)
        XCTAssertNil(WebViewOriginPolicy.origin(of: URL(string: "file:///etc/passwd")))
        XCTAssertNil(WebViewOriginPolicy.origin(of: nil))
        // WebKit reports port 0 for a default port; that must normalise the same.
        XCTAssertEqual(
            WebViewOriginPolicy.origin(scheme: "https", host: "example.com", port: 0),
            "https://example.com"
        )
        XCTAssertEqual(
            WebViewOriginPolicy.origin(scheme: "http", host: "EXAMPLE.com", port: 8080),
            "http://example.com:8080"
        )
        XCTAssertNil(WebViewOriginPolicy.origin(scheme: "file", host: "", port: 0))
        XCTAssertNil(WebViewOriginPolicy.origin(scheme: "https", host: "", port: 0))
    }

    // MARK: - allowedOrigins prop

    func testReplaceAllowedOriginsOverwritesTheDerivedDefault() {
        let policy = WebViewOriginPolicy()
        policy.recordSource(of: URL(string: "https://app.example.com/")!)

        policy.replaceAllowedOrigins(["https://cdn.example.com", "https://other.example.com/", "HTTPS://UPPER.example"])

        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "https://app.example.com/"), isExplicitSourceLoad: false))
        XCTAssertTrue(policy.isNavigationAllowed(URL(string: "https://cdn.example.com/x"), isExplicitSourceLoad: false))
        XCTAssertTrue(policy.isNavigationAllowed(URL(string: "https://other.example.com/x"), isExplicitSourceLoad: false))
        XCTAssertTrue(policy.isNavigationAllowed(URL(string: "https://upper.example/x"), isExplicitSourceLoad: false))
        XCTAssertTrue(policy.isMessageOriginAllowed(scheme: "https", host: "cdn.example.com", port: 0))
    }

    func testReplaceAllowedOriginsDropsUnusableEntries() {
        let policy = WebViewOriginPolicy()
        policy.replaceAllowedOrigins(["https://ok.example.com", "javascript:alert(1)", "", "nonsense"])
        XCTAssertEqual(policy.allowedOrigins, ["https://ok.example.com"])
    }

    func testHostOriginsCannotAllowlistAboutBlank() {
        let policy = WebViewOriginPolicy()
        policy.recordSource(of: URL(string: "https://app.example.com/")!)
        policy.replaceAllowedOrigins(["about:blank", "https://ok.example.com"])

        XCTAssertEqual(policy.allowedOrigins, ["https://ok.example.com"])
        // about:blank stays limited to inline HTML, which the app loads itself.
        XCTAssertFalse(policy.isMessageOriginAllowed(scheme: "about", host: "blank", port: 0))
    }

    func testRecordingASourceReplacesTheDerivedOrigin() {
        let policy = WebViewOriginPolicy()
        policy.recordSource(of: URL(string: "https://a.example.com/")!)
        policy.recordSource(of: URL(string: "https://b.example.com/")!)

        XCTAssertEqual(policy.derivedOrigins, ["https://b.example.com"])
        XCTAssertEqual(policy.allowedOrigins, ["https://b.example.com"])
    }

    // MARK: - Inline HTML

    func testInlineHtmlIsOpaqueUntilTheAppLoadsIt() {
        let policy = WebViewOriginPolicy()
        XCTAssertFalse(policy.allowsAboutBlank)
        XCTAssertFalse(policy.isMessageOriginAllowed(scheme: "", host: "", port: 0))
        XCTAssertFalse(policy.isMessageOriginAllowed(scheme: "about", host: "blank", port: 0))
        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "about:blank"), isExplicitSourceLoad: false))

        policy.recordInlineHTML()

        XCTAssertTrue(policy.allowsAboutBlank)
        XCTAssertTrue(policy.isNavigationAllowed(URL(string: "about:blank"), isExplicitSourceLoad: false))
        XCTAssertTrue(policy.isMessageOriginAllowed(scheme: "about", host: "blank", port: 0))
        XCTAssertTrue(policy.isMessageOriginAllowed(scheme: "", host: "", port: 0))
    }

    func testInlineHtmlDoesNotAllowRemoteOrigins() {
        let policy = WebViewOriginPolicy()
        policy.recordInlineHTML()
        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "https://evil.example.com/"), isExplicitSourceLoad: false))
        XCTAssertFalse(policy.isMessageOriginAllowed(scheme: "https", host: "evil.example.com", port: 0))
    }

    func testNilSecurityOriginIsAlwaysDropped() {
        let policy = WebViewOriginPolicy()
        policy.recordInlineHTML()
        policy.replaceAllowedOrigins(["https://app.example.com"])
        XCTAssertFalse(policy.isMessageOriginAllowed(nil))
    }

    // MARK: - Factory wiring

    func testFactoryInstallsPolicyAndNavigationDelegateAtCreateView() throws {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)
        defer { factory.destroyView(view: webView) }

        // A web view with only a `message` listener used to have NO navigation
        // delegate at all, so nothing policed where it could go.
        XCTAssertNotNil(webView.navigationDelegate)

        // A `file://` source is refused and never handed to WebKit.
        factory.updateProp(view: webView, key: "source", value: ["uri": "file:///etc/passwd"])
        XCTAssertNil(webView.url)

        // A `javascript:` source is refused too.
        factory.updateProp(view: webView, key: "source", value: ["uri": "javascript:alert(1)"])
        XCTAssertNil(webView.url)
    }

    // The batch VWebView.ts sends is `source` followed by `allowedOrigins`
    // (possibly `[]`). Before the origin split, `allowedOrigins: []` emptied the
    // origin that `source` had just recorded, so WebKit cancelled the initial
    // navigation and messages from the page were dropped.

    func testEmptyAllowedOriginsKeepsTheSourceOriginAllowed() throws {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)
        defer { factory.destroyView(view: webView) }

        factory.updateProp(view: webView, key: "source", value: ["uri": "https://example.com/a"])
        factory.updateProp(view: webView, key: "allowedOrigins", value: [String]())
        let policy = factory.policy(for: webView)

        XCTAssertTrue(policy.isNavigationAllowed(URL(string: "https://example.com/b"), isExplicitSourceLoad: false))
        XCTAssertTrue(policy.isMessageOriginAllowed(scheme: "https", host: "example.com", port: 0))
    }

    func testAllowedOriginsReplacesTheSourceOriginRegardlessOfPropOrder() throws {
        let sourceFirst = try makeWebView(steps: [
            ("source", ["uri": "https://example.com/a"]),
            ("allowedOrigins", ["https://other.com"]),
        ])
        let allowedFirst = try makeWebView(steps: [
            ("allowedOrigins", ["https://other.com"]),
            ("source", ["uri": "https://example.com/a"]),
        ])
        defer {
            sourceFirst.factory.destroyView(view: sourceFirst.webView)
            allowedFirst.factory.destroyView(view: allowedFirst.webView)
        }

        for (name, factory, webView) in [
            ("source first", sourceFirst.factory, sourceFirst.webView),
            ("allowedOrigins first", allowedFirst.factory, allowedFirst.webView),
        ] {
            let policy = factory.policy(for: webView)
            XCTAssertEqual(policy.allowedOrigins, ["https://other.com"], name)
            XCTAssertFalse(
                policy.isNavigationAllowed(URL(string: "https://example.com/b"), isExplicitSourceLoad: false),
                name
            )
        }
    }

    func testClearingAllowedOriginsRestoresTheSourceOrigin() throws {
        // `null` arrives as nil on iOS and as NSNull from some bridges; both
        // mean "no host override", so both must restore the derived origin.
        for cleared in [nil, NSNull()] as [Any?] {
            let factory = VWebViewFactory()
            let webView = try XCTUnwrap(factory.createView() as? WKWebView)
            defer { factory.destroyView(view: webView) }

            factory.updateProp(view: webView, key: "source", value: ["uri": "https://example.com/a"])
            factory.updateProp(view: webView, key: "allowedOrigins", value: ["https://other.com"])
            factory.updateProp(view: webView, key: "allowedOrigins", value: cleared)

            let policy = factory.policy(for: webView)
            XCTAssertTrue(
                policy.isNavigationAllowed(URL(string: "https://example.com/b"), isExplicitSourceLoad: false),
                "clearing with \(String(describing: cleared)) must restore the source origin"
            )
        }
    }

    func testNonArrayAllowedOriginsIsTreatedAsEmpty() throws {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)
        defer { factory.destroyView(view: webView) }

        factory.updateProp(view: webView, key: "source", value: ["uri": "https://example.com/a"])
        // The bridge only ever sends an array; a bare string is not a list.
        factory.updateProp(view: webView, key: "allowedOrigins", value: "https://other.com")

        XCTAssertEqual(factory.policy(for: webView).allowedOrigins, ["https://example.com"])
    }

    func testSourceChangeReplacesThePreviousSourceOrigin() throws {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)
        defer { factory.destroyView(view: webView) }

        factory.updateProp(view: webView, key: "source", value: ["uri": "https://a.example.com/"])
        factory.updateProp(view: webView, key: "source", value: ["uri": "https://b.example.com/"])
        let policy = factory.policy(for: webView)

        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "https://a.example.com/x"), isExplicitSourceLoad: false))
        XCTAssertFalse(policy.isMessageOriginAllowed(scheme: "https", host: "a.example.com", port: 0))
        XCTAssertTrue(policy.isNavigationAllowed(URL(string: "https://b.example.com/x"), isExplicitSourceLoad: false))
    }

    func testInlineHtmlWithHostOriginsStillAllowsAboutBlankMessages() throws {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)
        defer { factory.destroyView(view: webView) }

        factory.updateProp(view: webView, key: "source", value: ["html": "<p>Inline</p>"])
        factory.updateProp(view: webView, key: "allowedOrigins", value: ["https://x.com"])
        let policy = factory.policy(for: webView)

        XCTAssertTrue(policy.isNavigationAllowed(URL(string: "about:blank"), isExplicitSourceLoad: false))
        XCTAssertTrue(policy.isMessageOriginAllowed(scheme: "about", host: "blank", port: 0))
        XCTAssertTrue(policy.isMessageOriginAllowed(scheme: "", host: "", port: 0))
        XCTAssertTrue(policy.isMessageOriginAllowed(scheme: "https", host: "x.com", port: 0))
    }

    /// Applies the props in order to a fresh web view. The factory is returned
    /// with the web view so the caller can inspect the policy it installed.
    private func makeWebView(
        steps: [(String, Any?)]
    ) throws -> (factory: VWebViewFactory, webView: WKWebView) {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)
        for (key, value) in steps {
            factory.updateProp(view: webView, key: key, value: value)
        }
        return (factory, webView)
    }

    func testFactoryDestroyViewClearsThePolicy() throws {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)
        factory.updateProp(view: webView, key: "source", value: ["uri": "https://app.example.com/"])
        factory.destroyView(view: webView)
        XCTAssertNil(webView.navigationDelegate)
    }
}
#endif
