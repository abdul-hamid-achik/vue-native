import AppKit
import WebKit
import ObjectiveC

/// Factory for VWebView — wraps WKWebView for macOS.
/// Supports loading URLs and inline HTML, plus load/error/loadStart/message events.
final class VWebViewFactory: NativeComponentFactory {

    // nonisolated(unsafe) for keys accessed from WKNavigationDelegate callbacks
    nonisolated(unsafe) fileprivate static var onLoadKey: UInt8 = 0
    nonisolated(unsafe) fileprivate static var onErrorKey: UInt8 = 1
    nonisolated(unsafe) fileprivate static var onLoadStartKey: UInt8 = 2
    nonisolated(unsafe) fileprivate static var onMessageKey: UInt8 = 3
    fileprivate static var delegateKey: UInt8 = 4
    fileprivate static var msgHandlerKey: UInt8 = 5
    // nonisolated(unsafe): read from the WKNavigationDelegate / WKScriptMessageHandler
    // proxy classes, which are `@objc` and not actor-isolated.
    nonisolated(unsafe) fileprivate static var policyKey: UInt8 = 6

    /// Diagnostic for a blocked navigation or message. Never fails silently:
    /// a dropped origin is a configuration problem the app needs to see.
    fileprivate static func logBlocked(_ message: String) {
        NSLog("[VueNative VWebView] %@", message)
    }

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.wantsLayer = true
        // Install the origin policy and its navigation delegate up front. Doing
        // this lazily from addEventListener left a web view with only a
        // `message` listener with NO navigation policy at all.
        objc_setAssociatedObject(
            webView, &VWebViewFactory.policyKey,
            WebViewOriginPolicy(),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        ensureDelegate(for: webView)
        webView.ensureLayoutNode()
        return webView
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let webView = view as? WKWebView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "source", "uri":
            if let dict = value as? [String: Any] {
                if let uri = dict["uri"] as? String {
                    loadRequestedURI(uri, in: webView)
                } else if let html = dict["html"] as? String {
                    loadInlineHTML(html, in: webView)
                }
            } else if let urlString = value as? String {
                loadRequestedURI(urlString, in: webView)
            }

        case "html":
            if let html = value as? String {
                loadInlineHTML(html, in: webView)
            }

        case "allowedOrigins":
            // Replaces (does not extend) the origin derived from `source`.
            policy(for: webView).replaceAllowedOrigins(Self.originValues(from: value))

        case "javaScriptEnabled":
            webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = value as? Bool ?? true

        case "scrollEnabled":
            // On macOS, WKWebView uses an enclosing scroll view
            if let enabled = value as? Bool {
                webView.enclosingScrollView?.hasVerticalScroller = enabled
                webView.enclosingScrollView?.hasHorizontalScroller = enabled
            }

        case "userAgent":
            if let ua = value as? String {
                webView.customUserAgent = ua
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
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

        case "loadStart":
            objc_setAssociatedObject(
                view, &VWebViewFactory.onLoadStartKey,
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
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "vueNative")
            let msgHandler = MacWebViewMessageHandler(view: view)
            webView.configuration.userContentController.add(msgHandler, name: "vueNative")
            objc_setAssociatedObject(
                view, &VWebViewFactory.msgHandlerKey,
                msgHandler,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        switch event {
        case "load":
            objc_setAssociatedObject(view, &VWebViewFactory.onLoadKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "error":
            objc_setAssociatedObject(view, &VWebViewFactory.onErrorKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "loadStart":
            objc_setAssociatedObject(view, &VWebViewFactory.onLoadStartKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "message":
            objc_setAssociatedObject(view, &VWebViewFactory.onMessageKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if let webView = view as? WKWebView {
                webView.configuration.userContentController.removeScriptMessageHandler(forName: "vueNative")
            }
            objc_setAssociatedObject(view, &VWebViewFactory.msgHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default:
            break
        }
    }

    func destroyView(view: NSView) {
        guard let webView = view as? WKWebView else { return }
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "vueNative")
        objc_setAssociatedObject(view, &VWebViewFactory.onLoadKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VWebViewFactory.onErrorKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VWebViewFactory.onLoadStartKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VWebViewFactory.onMessageKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VWebViewFactory.delegateKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VWebViewFactory.msgHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VWebViewFactory.policyKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - Helpers

    /// The policy installed by `createView`. Recreated defensively if a caller
    /// hands us a web view this factory did not build.
    private func policy(for webView: WKWebView) -> WebViewOriginPolicy {
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

    /// Load the URI the app declared through the `source` / `uri` prop.
    ///
    /// The origin is allowlisted first so the initial navigation — which comes
    /// back through `decidePolicyFor` as a non-explicit action — is permitted,
    /// and so messages from the app's own content work with no configuration.
    /// Non-http(s) schemes are refused outright.
    private func loadRequestedURI(_ uri: String, in webView: WKWebView) {
        guard let url = URL(string: uri) else {
            VWebViewFactory.logBlocked("Blocked navigation to unparseable URI")
            return
        }
        let policy = self.policy(for: webView)
        guard policy.isNavigationAllowed(url, isExplicitSourceLoad: true) else {
            VWebViewFactory.logBlocked("Blocked VWebView source with disallowed scheme: \(url.absoluteString)")
            return
        }
        policy.allowOrigin(of: url)
        webView.load(URLRequest(url: url))
    }

    /// Load inline HTML. Reports an `about:blank` origin, so that origin is
    /// allowlisted for messages.
    private func loadInlineHTML(_ html: String, in webView: WKWebView) {
        policy(for: webView).enableAboutBlank()
        webView.loadHTMLString(html, baseURL: nil)
    }

    /// Accept `allowedOrigins` as an array of strings or a comma-separated string.
    static func originValues(from value: Any?) -> [String] {
        if let array = value as? [String] { return array }
        if let array = value as? [Any] { return array.compactMap { $0 as? String } }
        if let text = value as? String {
            return text.split(separator: ",").map { String($0) }
        }
        return []
    }

    private func ensureDelegate(for webView: WKWebView) {
        guard !(webView.navigationDelegate is MacWebViewDelegate) else { return }
        let delegate = MacWebViewDelegate(view: webView)
        objc_setAssociatedObject(
            webView, &VWebViewFactory.delegateKey,
            delegate,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        webView.navigationDelegate = delegate
    }
}

// MARK: - MacWebViewMessageHandler

private final class MacWebViewMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var view: NSView?

    init(view: NSView) { self.view = view }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let view else { return }
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

// MARK: - MacWebViewDelegate

private final class MacWebViewDelegate: NSObject, WKNavigationDelegate {
    private weak var view: NSView?

    init(view: NSView) { self.view = view }

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

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard let view = view else { return }
        let handler = objc_getAssociatedObject(view, &VWebViewFactory.onLoadStartKey) as? ((Any?) -> Void)
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
