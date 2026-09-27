package com.vuenative.core

import android.content.Context
import android.os.Build
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONArray
import org.json.JSONObject

/**
 * Factory for `VWebView`.
 *
 * The web view runs remote content with JavaScript enabled and exposes a
 * `vueNative` bridge into the Vue app's event stream, so every navigation and
 * every inbound message is checked against a [WebViewOriginPolicy]. The policy
 * is safe by default: it is seeded only from the URI or inline HTML the app
 * itself supplied. See [WebViewOriginPolicy] for the threat model.
 */
class VWebViewFactory : NativeComponentFactory {
    private val loadHandlers = mutableMapOf<WebView, (Any?) -> Unit>()
    private val errorHandlers = mutableMapOf<WebView, (Any?) -> Unit>()
    private val messageHandlers = mutableMapOf<WebView, (Any?) -> Unit>()
    private val policies = mutableMapOf<WebView, WebViewOriginPolicy>()

    override fun createView(context: Context): View {
        return WebView(context).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            // Deny local-file and cross-origin file access. `file://` sources are
            // refused by the origin policy anyway; these flags stop a loaded page
            // from reaching the filesystem through XHR/fetch.
            @Suppress("DEPRECATION")
            settings.allowFileAccess = false
            @Suppress("DEPRECATION")
            settings.allowContentAccess = false
            @Suppress("DEPRECATION")
            settings.allowFileAccessFromFileURLs = false
            @Suppress("DEPRECATION")
            settings.allowUniversalAccessFromFileURLs = false
            settings.javaScriptCanOpenWindowsAutomatically = false
            // Asymmetric getter/setter pair, so Kotlin exposes no synthetic property.
            settings.setSupportMultipleWindows(false)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            policies[this] = WebViewOriginPolicy()
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    val url = request.url?.toString()
                    if (!policyFor(view).isNavigationAllowed(url, isExplicitSourceLoad = false)) {
                        logBlocked("Blocked VWebView navigation to non-allowlisted URL: $url")
                        return true
                    }
                    return false
                }

                @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
                override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) return false
                    if (!policyFor(view).isNavigationAllowed(url, isExplicitSourceLoad = false)) {
                        logBlocked("Blocked VWebView navigation to non-allowlisted URL: $url")
                        return true
                    }
                    return false
                }

                override fun onPageFinished(view: WebView, url: String) {
                    loadHandlers[view]?.invoke(mapOf("url" to url))
                }

                override fun onReceivedError(view: WebView, req: WebResourceRequest, err: WebResourceError) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && req.isForMainFrame) {
                        emitError(view, err.description.toString(), req.url?.toString() ?: "")
                    }
                }

                @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
                override fun onReceivedError(
                    view: WebView,
                    errorCode: Int,
                    description: String,
                    failingUrl: String
                ) {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                        emitError(view, description, failingUrl)
                    }
                }
            }
            webChromeClient = WebChromeClient()
            // JavaScript bridge for message passing
            addJavascriptInterface(object {
                @android.webkit.JavascriptInterface
                fun postMessage(msg: String) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        val wv = this@apply
                        // Origin check. Without it any page reachable inside the
                        // web view can inject arbitrary payloads into the Vue
                        // app's event stream.
                        if (!policyFor(wv).isMessageOriginAllowed(wv.url)) {
                            logBlocked("Dropped VWebView message from non-allowlisted origin: ${wv.url}")
                            return@post
                        }
                        messageHandlers[wv]?.invoke(mapOf("data" to msg))
                    }
                }
            }, "vueNative")
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val wv = view as? WebView ?: return
        when (key) {
            "source" -> {
                val src = value
                val uri = when (src) {
                    is Map<*, *> -> src["uri"]?.toString()
                    is JSONObject -> src.optString("uri")
                    else -> null
                }
                val html = when (src) {
                    is Map<*, *> -> src["html"]?.toString()
                    is JSONObject -> src.optString("html")
                    else -> null
                }
                when {
                    uri != null && uri.isNotEmpty() -> loadRequestedUri(wv, uri)
                    html != null && html.isNotEmpty() -> loadInlineHtml(wv, html)
                }
            }
            "allowedOrigins" -> {
                // Replaces (does not extend) the origin derived from `source`.
                policyFor(wv).replaceAllowedOrigins(originValues(value))
            }
            "javaScriptEnabled" -> wv.settings.javaScriptEnabled = value != false
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val wv = view as? WebView ?: return
        when (event) {
            "load" -> loadHandlers[wv] = handler
            "error" -> errorHandlers[wv] = handler
            "message" -> messageHandlers[wv] = handler
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val wv = view as? WebView ?: return
        when (event) {
            "load" -> loadHandlers.remove(wv)
            "error" -> errorHandlers.remove(wv)
            "message" -> messageHandlers.remove(wv)
        }
    }

    override fun destroyView(view: View) {
        val wv = view as? WebView ?: return
        loadHandlers.remove(wv)
        errorHandlers.remove(wv)
        messageHandlers.remove(wv)
        policies.remove(wv)
        wv.stopLoading()
        wv.removeJavascriptInterface("vueNative")
        wv.webViewClient = WebViewClient()
        wv.webChromeClient = null
        wv.removeAllViews()
        wv.destroy()
    }

    /**
     * Load the URI the app declared through the `source` prop.
     *
     * The origin is allowlisted first so messages from the app's own content work
     * with no configuration. Non-http(s) schemes are refused outright.
     */
    private fun loadRequestedUri(wv: WebView, uri: String) {
        val policy = policyFor(wv)
        if (!policy.isNavigationAllowed(uri, isExplicitSourceLoad = true)) {
            logBlocked("Blocked VWebView source with disallowed scheme: $uri")
            return
        }
        policy.allowOrigin(uri)
        wv.loadUrl(uri)
    }

    /** Load inline HTML, which reports an opaque origin. */
    private fun loadInlineHtml(wv: WebView, html: String) {
        policyFor(wv).enableAboutBlank()
        wv.loadData(html, "text/html", "UTF-8")
    }

    private fun policyFor(wv: WebView): WebViewOriginPolicy =
        policies.getOrPut(wv) { WebViewOriginPolicy() }

    private fun emitError(view: WebView, message: String, url: String) {
        errorHandlers[view]?.invoke(
            mapOf(
                "message" to message,
                "url" to url
            )
        )
    }

    private fun logBlocked(message: String) {
        Log.w(TAG, message)
    }

    companion object {
        private const val TAG = "VueNative-WebView"

        /** Accept `allowedOrigins` as a list, a JSONArray, or a comma-separated string. */
        internal fun originValues(value: Any?): List<String> = when (value) {
            is List<*> -> value.mapNotNull { it?.toString() }
            is JSONArray -> (0 until value.length()).mapNotNull { value.opt(it)?.toString() }
            is Array<*> -> value.mapNotNull { it?.toString() }
            is String -> value.split(",").map { it.trim() }.filter { it.isNotEmpty() }
            else -> emptyList()
        }
    }
}
