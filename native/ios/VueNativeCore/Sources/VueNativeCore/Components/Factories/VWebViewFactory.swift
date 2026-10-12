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
    // nonisolated(unsafe) allows usage from non-isolated contexts (WKNavigationDelegate,
    // WKScriptMessageHandler callbacks) without actor-isolation errors.
    nonisolated(unsafe) fileprivate static var onLoadKey: UInt8 = 0
    nonisolated(unsafe) fileprivate static var onErrorKey: UInt8 = 1
    nonisolated(unsafe) fileprivate static var onMessageKey: UInt8 = 2
    fileprivate static var delegateKey: UInt8 = 3
    fileprivate static var msgHandlerKey: UInt8 = 4
    // nonisolated(unsafe): read from the WKNavigationDelegate / WKScriptMessageHandler
    // callbacks, which are not actor-isolated.
    nonisolated(unsafe) fileprivate static var policyKey: UInt8 = 5

    /// Diagnostic for a blocked navigation or message. Never fails silently:
    /// a dropped origin is a configuration problem the app needs to see.
    nonisolated fileprivate static func logBlocked(_ message: String) {
        NSLog("[VueNative VWebView] %@", message)
    }

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let config  = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = true
        // Install the origin policy and its navigation delegate up front. Doing
        // this lazily from addEventListener left a web view with only a
        // `message` listener with NO navigation policy at all.
        objc_setAssociatedObject(
            webView, &VWebViewFactory.policyKey,
            WebViewOriginPolicy(),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        ensureDelegate(for: webView)
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
                if let uri = dict["uri"] as? String {
                    loadRequestedURI(uri, in: webView)
                } else if let html = dict["html"] as? String {
                    loadInlineHTML(html, in: webView)
                }
            }
        case "allowedOrigins":
            // Replaces (does not extend) the origin derived from `source`. An empty
            // list, `null` or a non-array value restores that derived origin.
            policy(for: webView).replaceAllowedOrigins(Self.originValues(from: value))
        case "javaScriptEnabled":
            webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = value as? Bool ?? true
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
            objc_setAssociatedObject(view, &VWebViewFactory.onLoadKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "error":
            objc_setAssociatedObject(view, &VWebViewFactory.onErrorKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
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

    func destroyView(view: UIView) {
        guard let webView = view as? WKWebView else { return }
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "vueNative")
        objc_setAssociatedObject(view, &VWebViewFactory.onLoadKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VWebViewFactory.onErrorKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VWebViewFactory.onMessageKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VWebViewFactory.delegateKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VWebViewFactory.msgHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VWebViewFactory.policyKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - Helpers

    /// The policy installed by `createView`. Recreated defensively if a caller
    /// hands us a web view this factory did not build. Internal so the wiring
    /// tests can read the decisions the factory actually made.
    func policy(for webView: WKWebView) -> WebViewOriginPolicy {
        if let existing = objc_getAssociatedObject(webView, &VWebViewFactory.policyKey) as? WebViewOriginPolicy {
            return existing
        }
        let policy = WebViewOriginPolicy()
        objc_setAssociatedObject(
            webView, &VWebViewFactory.policyKey,
            policy,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return policy
    }

    /// Load the URI the app declared through the `source` prop.
    ///
    /// The origin is recorded first, replacing the previous source's origin, so
    /// the initial navigation — which WebKit reports to `decidePolicyFor` as a
    /// non-explicit action — is permitted and messages from the app's own content
    /// work with no configuration. A host `allowedOrigins` prop replaces that
    /// default; a prop that omits the source origin also cancels the source's own
    /// initial navigation. Non-http(s) schemes are refused outright.
    private func loadRequestedURI(_ uri: String, in webView: WKWebView) {
        guard let url = URL(string: uri) else {
            VWebViewFactory.logBlocked("Blocked navigation to unparseable URI")
            return
        }
        let policy = self.policy(for: webView)
        // Recorded before the scheme check, so a refused source also stops
        // trusting the page it replaces.
        policy.recordSource(of: url)
        guard policy.isNavigationAllowed(url, isExplicitSourceLoad: true) else {
            VWebViewFactory.logBlocked("Blocked VWebView source with disallowed scheme: \(url.absoluteString)")
            return
        }
        webView.load(URLRequest(url: url))
    }

    /// Load inline HTML. Reports an `about:blank` origin, which becomes the
    /// derived origin for messages and replaces any previous source origin.
    private func loadInlineHTML(_ html: String, in webView: WKWebView) {
        policy(for: webView).recordInlineHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }

    /// Accept `allowedOrigins` only as an array of strings. Anything else
    /// (`null`, `NSNull`, a bare string, a number) is an empty list.
    static func originValues(from value: Any?) -> [String] {
        if let array = value as? [String] { return array }
        if let array = value as? [Any] { return array.compactMap { $0 as? String } }
        return []
    }

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

    /// Enforce the origin allowlist on EVERY navigation, including subframes and
    /// `window.open` (which arrives with `targetFrame == nil`). Special-casing
    /// the main frame would leave a popup as an escape hatch.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let url = navigationAction.request.url
        let policy = objc_getAssociatedObject(webView, &VWebViewFactory.policyKey) as? WebViewOriginPolicy
        // No policy means we cannot make a safe decision — fail closed.
        guard let policy, policy.isNavigationAllowed(url, isExplicitSourceLoad: false) else {
            VWebViewFactory.logBlocked(
                "Blocked VWebView navigation to non-allowlisted URL: \(url?.absoluteString ?? "<nil>")"
            )
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

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
        // Origin check. Without it any page reachable inside the web view can
        // inject arbitrary payloads into the Vue app's event stream.
        let policy = objc_getAssociatedObject(view, &VWebViewFactory.policyKey) as? WebViewOriginPolicy
        guard let policy, policy.isMessageOriginAllowed(message.frameInfo.securityOrigin) else {
            let origin = message.frameInfo.securityOrigin
            VWebViewFactory.logBlocked(
                "Dropped VWebView message from non-allowlisted origin: "
                + "\(origin.protocol)://\(origin.host):\(origin.port)"
            )
            return
        }
        let handler = objc_getAssociatedObject(view, &VWebViewFactory.onMessageKey) as? ((Any?) -> Void)
        handler?(["data": message.body])
    }
}
#endif
