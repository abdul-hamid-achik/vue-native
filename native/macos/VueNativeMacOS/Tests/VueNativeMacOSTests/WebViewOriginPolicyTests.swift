import AppKit
import Foundation
import WebKit
import XCTest
@testable import VueNativeMacOS

/// Regression tests for P1-4 on macOS: `VWebView` must not load arbitrary URIs
/// and must not forward `postMessage` payloads from origins the app did not
/// declare. Mirrors the iOS `WebViewOriginPolicyTests`.
///
/// `@MainActor` because the factory-wiring cases touch `VWebViewFactory`, whose
/// `NativeComponentFactory` conformance is main-actor isolated.
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

    func testExplicitSourceIsAllowedAndSeedsTheAllowlist() throws {
        let policy = WebViewOriginPolicy()
        let source = try XCTUnwrap(URL(string: "https://app.example.com/page"))
        XCTAssertTrue(policy.isNavigationAllowed(source, isExplicitSourceLoad: true))
        // A redirect to the same origin is refused until the app records it.
        XCTAssertFalse(policy.isNavigationAllowed(source, isExplicitSourceLoad: false))

        policy.allowOrigin(of: source)
        XCTAssertTrue(
            policy.isNavigationAllowed(URL(string: "https://app.example.com/other"), isExplicitSourceLoad: false)
        )
        XCTAssertTrue(policy.isMessageOriginAllowed(scheme: "https", host: "app.example.com", port: 0))
    }

    func testAllowlistingOneOriginDoesNotAllowAnother() throws {
        let policy = WebViewOriginPolicy()
        policy.allowOrigin(of: try XCTUnwrap(URL(string: "https://app.example.com/")))

        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "https://evil.example.com/"), isExplicitSourceLoad: false))
        XCTAssertFalse(policy.isMessageOriginAllowed(scheme: "https", host: "evil.example.com", port: 0))
        // A different port is a different origin.
        XCTAssertFalse(
            policy.isNavigationAllowed(URL(string: "https://app.example.com:8443/"), isExplicitSourceLoad: false)
        )
        // So is a downgrade to plain http.
        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "http://app.example.com/"), isExplicitSourceLoad: false))
    }

    func testNonHttpSourceNeverWidensTheAllowlist() throws {
        let policy = WebViewOriginPolicy()
        policy.allowOrigin(of: try XCTUnwrap(URL(string: "file:///etc/passwd")))
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
        XCTAssertEqual(
            WebViewOriginPolicy.origin(scheme: "https", host: "example.com", port: 0),
            "https://example.com",
            "WebKit reports port 0 for a default port"
        )
        XCTAssertEqual(
            WebViewOriginPolicy.origin(scheme: "http", host: "EXAMPLE.com", port: 8080),
            "http://example.com:8080"
        )
        XCTAssertNil(WebViewOriginPolicy.origin(scheme: "file", host: "", port: 0))
        XCTAssertNil(WebViewOriginPolicy.origin(scheme: "https", host: "", port: 0))
    }

    // MARK: - allowedOrigins prop

    func testReplaceAllowedOriginsOverwritesTheDerivedDefault() throws {
        let policy = WebViewOriginPolicy()
        policy.allowOrigin(of: try XCTUnwrap(URL(string: "https://app.example.com/")))

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

    // MARK: - Inline HTML

    func testInlineHtmlIsOpaqueUntilTheAppLoadsIt() {
        let policy = WebViewOriginPolicy()
        XCTAssertFalse(policy.allowsAboutBlank)
        XCTAssertFalse(policy.isMessageOriginAllowed(scheme: "", host: "", port: 0))
        XCTAssertFalse(policy.isMessageOriginAllowed(scheme: "about", host: "blank", port: 0))
        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "about:blank"), isExplicitSourceLoad: false))

        policy.enableAboutBlank()

        XCTAssertTrue(policy.allowsAboutBlank)
        XCTAssertTrue(policy.isNavigationAllowed(URL(string: "about:blank"), isExplicitSourceLoad: false))
        XCTAssertTrue(policy.isMessageOriginAllowed(scheme: "about", host: "blank", port: 0))
        XCTAssertTrue(policy.isMessageOriginAllowed(scheme: "", host: "", port: 0))
    }

    func testInlineHtmlDoesNotAllowRemoteOrigins() {
        let policy = WebViewOriginPolicy()
        policy.enableAboutBlank()
        XCTAssertFalse(policy.isNavigationAllowed(URL(string: "https://evil.example.com/"), isExplicitSourceLoad: false))
        XCTAssertFalse(policy.isMessageOriginAllowed(scheme: "https", host: "evil.example.com", port: 0))
    }

    func testNilSecurityOriginIsAlwaysDropped() {
        let policy = WebViewOriginPolicy()
        policy.enableAboutBlank()
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

        factory.updateProp(view: webView, key: "source", value: ["uri": "file:///etc/passwd"])
        XCTAssertNil(webView.url)

        factory.updateProp(view: webView, key: "source", value: ["uri": "javascript:alert(1)"])
        XCTAssertNil(webView.url)

        // The bare-string `uri` prop shape must be policed identically.
        factory.updateProp(view: webView, key: "uri", value: "file:///etc/passwd")
        XCTAssertNil(webView.url)
    }

    func testFactoryDestroyViewClearsTheNavigationDelegate() throws {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)
        factory.updateProp(view: webView, key: "source", value: ["uri": "https://app.example.com/"])
        factory.destroyView(view: webView)
        XCTAssertNil(webView.navigationDelegate)
    }
}
