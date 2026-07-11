import AppKit
import WebKit
import XCTest
@testable import VueNativeMacOS

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

    func testInitialHTMLDoesNotExecuteJavaScriptWhenDisabled() async throws {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)
        defer { factory.destroyView(view: webView) }

        let loaded = expectation(description: "Initial HTML finishes loading")
        let scriptMessage = expectation(description: "Disabled initial script does not execute")
        scriptMessage.isInverted = true
        factory.addEventListener(view: webView, event: "load") { _ in loaded.fulfill() }
        factory.addEventListener(view: webView, event: "message") { _ in scriptMessage.fulfill() }

        factory.updateProp(view: webView, key: "javaScriptEnabled", value: false)
        factory.updateProp(
            view: webView,
            key: "source",
            value: [
                "html": "<script>window.webkit.messageHandlers.vueNative.postMessage('unexpected')</script><p>Loaded</p>"
            ]
        )

        await fulfillment(of: [loaded], timeout: 5)
        await fulfillment(of: [scriptMessage], timeout: 0.25)
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

    func testMessageListenerReceivesWebContentAndStopsAfterRemoval() async throws {
        let factory = VWebViewFactory()
        let webView = try XCTUnwrap(factory.createView() as? WKWebView)
        let received = expectation(description: "Receives WebKit message")
        var messageCount = 0
        var receivedPayload: Any?
        factory.addEventListener(view: webView, event: "message") { payload in
            messageCount += 1
            receivedPayload = payload
            received.fulfill()
        }

        webView.loadHTMLString(
            "<script>window.webkit.messageHandlers.vueNative.postMessage('hello')</script>",
            baseURL: nil
        )
        await fulfillment(of: [received], timeout: 5)
        XCTAssertEqual((receivedPayload as? [String: String])?["data"], "hello")

        factory.removeEventListener(view: webView, event: "message")
        _ = try? await webView.evaluateJavaScript(
            "window.webkit.messageHandlers.vueNative.postMessage('ignored')"
        )
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(messageCount, 1)
        factory.destroyView(view: webView)
    }
}
