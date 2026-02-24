#if canImport(UIKit)
import UIKit
import WebKit
import ObjectiveC
import FlexLayout

// MARK: - VWebViewFactory

/// Factory for VWebView — wraps WKWebView with FlexLayout support.
/// Supports loading URLs and inline HTML, plus load/error/message events.
@MainActor
final class VWebViewFactory: NativeComponentFactory {

    // fileprivate so the inner delegate/handler classes in this file can access them.
    fileprivate static var onLoadKey:    UInt8 = 0
    fileprivate static var onErrorKey:   UInt8 = 1
    fileprivate static var onMessageKey: UInt8 = 2
    fileprivate static var delegateKey:  UInt8 = 3
    fileprivate static var msgHandlerKey: UInt8 = 4

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let config  = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = true
        // Touch FlexLayout so Yoga tracks this view
        _ = webView.flex
        return webView
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let webView = view as? WKWebView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }
        switch key {
        case "source":
            if let dict = value as? [String: Any] {
                if let uri = dict["uri"] as? String, let url = URL(string: uri) {
                    webView.load(URLRequest(url: url))
                } else if let html = dict["html"] as? String {
                    webView.loadHTMLString(html, baseURL: nil)
                }
            }
        case "javaScriptEnabled":
            // WKWebView has JS enabled by default; disabling requires WKPreferences on the
            // configuration object, which cannot be changed after init. Silently ignore.
            break
        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard let webView = view as? WKWebView else { return }
        switch event {
        case "load":
            objc_setAssociatedObject(
                view, &VWebViewFactory.onLoadKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            ensureDelegate(for: webView)
        case "error":
            objc_setAssociatedObject(
                view, &VWebViewFactory.onErrorKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            ensureDelegate(for: webView)
        case "message":
            objc_setAssociatedObject(
                view, &VWebViewFactory.onMessageKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            // Remove any previously registered handler to avoid accumulating duplicates
            // and to break the retain cycle (userContentController -> handler).
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "vueNative")
            let msgHandler = WebViewMessageHandler(view: view)
            webView.configuration.userContentController.add(msgHandler, name: "vueNative")
            // Store the handler via associated object so it can be referenced for cleanup
            objc_setAssociatedObject(
                view, &VWebViewFactory.msgHandlerKey,
                msgHandler,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        switch event {
        case "load":
            objc_setAssociatedObject(view, &VWebViewFactory.onLoadKey,    nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "error":
            objc_setAssociatedObject(view, &VWebViewFactory.onErrorKey,   nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "message":
            objc_setAssociatedObject(view, &VWebViewFactory.onMessageKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            // Remove the script message handler from WKUserContentController to break
            // the strong reference it holds to WebViewMessageHandler.
            if let webView = view as? WKWebView {
                webView.configuration.userContentController.removeScriptMessageHandler(forName: "vueNative")
            }
            objc_setAssociatedObject(view, &VWebViewFactory.msgHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default:
            break
        }
    }

    // MARK: - Helpers

    private func ensureDelegate(for webView: WKWebView) {
        guard !(webView.navigationDelegate is WebViewDelegate) else { return }
        let delegate = WebViewDelegate(view: webView)
        // Retain the delegate via an associated object (WKWebView only holds a weak ref)
        objc_setAssociatedObject(
            webView, &VWebViewFactory.delegateKey,
            delegate,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        webView.navigationDelegate = delegate
    }
}

// MARK: - WebViewDelegate

private final class WebViewDelegate: NSObject, WKNavigationDelegate {
    private weak var view: UIView?

    init(view: UIView) { self.view = view }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let view = view else { return }
        let handler = objc_getAssociatedObject(view, &VWebViewFactory.onLoadKey) as? ((Any?) -> Void)
        handler?(["url": webView.url?.absoluteString ?? ""])
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard let view = view else { return }
        let handler = objc_getAssociatedObject(view, &VWebViewFactory.onErrorKey) as? ((Any?) -> Void)
        handler?(["message": error.localizedDescription])
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        guard let view = view else { return }
        let handler = objc_getAssociatedObject(view, &VWebViewFactory.onErrorKey) as? ((Any?) -> Void)
        handler?(["message": error.localizedDescription])
    }
}

// MARK: - WebViewMessageHandler

private final class WebViewMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var view: UIView?

    init(view: UIView) { self.view = view }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let view = view else { return }
        let handler = objc_getAssociatedObject(view, &VWebViewFactory.onMessageKey) as? ((Any?) -> Void)
        handler?(["data": message.body])
    }
}
#endif
