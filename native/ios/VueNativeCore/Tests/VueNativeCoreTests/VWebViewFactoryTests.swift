#if canImport(UIKit)
import WebKit
import XCTest
@testable import VueNativeCore

@MainActor
final class VWebViewFactoryTests: XCTestCase {
    func testJavaScriptEnabledUpdatesPreferencesForFutureNavigations() throws {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)

        XCTAssertTrue(webView.configuration.defaultWebpagePreferences.allowsContentJavaScript)

        factory.updateProp(view: webView, key: "javaScriptEnabled", value: false)
        XCTAssertFalse(webView.configuration.defaultWebpagePreferences.allowsContentJavaScript)

        factory.updateProp(view: webView, key: "javaScriptEnabled", value: true)
        XCTAssertTrue(webView.configuration.defaultWebpagePreferences.allowsContentJavaScript)
    }

    func testInitialHTMLRetainsDisabledJavaScriptPolicy() throws {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)
        defer { factory.destroyView(view: webView) }

        factory.updateProp(view: webView, key: "javaScriptEnabled", value: false)
        factory.updateProp(
            view: webView,
            key: "source",
            value: [
                "html": "<script>window.webkit.messageHandlers.vueNative.postMessage('unexpected')</script><p>Loaded</p>"
            ]
        )

        // Swift-package iOS tests run as logic tests without UIApplication, so
        // WebKit cannot complete a real navigation here. Assert the native
        // policy remains disabled as the initial source is handed to WebKit;
        // the runtime test independently locks down that operation ordering.
        XCTAssertFalse(webView.configuration.defaultWebpagePreferences.allowsContentJavaScript)
    }

    func testDestroyViewClearsNavigationDelegateAndCallbacks() throws {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)
        var loadCount = 0
        factory.addEventListener(view: webView, event: "load") { _ in loadCount += 1 }
        let delegate = try XCTUnwrap(webView.navigationDelegate)

        factory.destroyView(view: webView)
        delegate.webView?(webView, didFinish: nil)

        XCTAssertNil(webView.navigationDelegate)
        XCTAssertNil(webView.uiDelegate)
        XCTAssertEqual(loadCount, 0)
    }
}
#endif
