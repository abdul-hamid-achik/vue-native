import AppKit
import WebKit
import ObjectiveC

/// Factory for VWebView — wraps WKWebView for macOS.
/// Supports loading URLs and inline HTML, plus load/error/loadStart events.
final class VWebViewFactory: NativeComponentFactory {

    // nonisolated(unsafe) for keys accessed from WKNavigationDelegate callbacks
    nonisolated(unsafe) fileprivate static var onLoadKey: UInt8 = 0
    nonisolated(unsafe) fileprivate static var onErrorKey: UInt8 = 1
    nonisolated(unsafe) fileprivate static var onLoadStartKey: UInt8 = 2
    fileprivate static var delegateKey: UInt8 = 3

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.wantsLayer = true
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
                if let uri = dict["uri"] as? String, let url = URL(string: uri) {
                    webView.load(URLRequest(url: url))
                } else if let html = dict["html"] as? String {
                    webView.loadHTMLString(html, baseURL: nil)
                }
            } else if let urlString = value as? String, let url = URL(string: urlString) {
                webView.load(URLRequest(url: url))
            }

        case "html":
            if let html = value as? String {
                webView.loadHTMLString(html, baseURL: nil)
            }

        case "javaScriptEnabled":
            // WKWebView has JS enabled by default; disabling requires WKPreferences on the
            // configuration object, which cannot be changed after init. Silently ignore.
            break

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
        default:
            break
        }
    }

    // MARK: - Helpers

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

// MARK: - MacWebViewDelegate

private final class MacWebViewDelegate: NSObject, WKNavigationDelegate {
    private weak var view: NSView?

    init(view: NSView) { self.view = view }

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
