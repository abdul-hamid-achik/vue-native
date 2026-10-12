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
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import java.util.concurrent.atomic.AtomicBoolean
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
 *
 * Messages arrive through a `WebViewCompat` web message listener when the WebView
 * supports it, so the source origin and frame of every message are checked, in
 * subframes too. [legacyBridgeOnly] forces the older `addJavascriptInterface`
 * bridge, which only sees the main frame, for WebViews without the listener.
 */
class VWebViewFactory(private val legacyBridgeOnly: Boolean = false) : NativeComponentFactory {
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
            // Message passing. The listener sees each message's source origin and
            // frame, so the origin policy applies in every frame.
            if (!legacyBridgeOnly && WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
                WebViewCompat.addWebMessageListener(this, BRIDGE_NAME, setOf("*")) { view, message, sourceOrigin, isMainFrame, _ ->
                    handleWebMessage(view, message.data, sourceOrigin.toString(), isMainFrame)
                }
            } else {
                warnLegacyBridgeOnce()
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
                }, BRIDGE_NAME)
            }
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
        if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            WebViewCompat.removeWebMessageListener(wv, BRIDGE_NAME)
        }
        wv.removeJavascriptInterface(BRIDGE_NAME)
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
        // Record the source before checking it, so a refused source also drops the
        // previous source's origin rather than leaving it allowed.
        policy.allowOrigin(uri)
        if (!policy.isNavigationAllowed(uri, isExplicitSourceLoad = true)) {
            logBlocked("Blocked VWebView source with disallowed scheme: $uri")
            return
        }
        wv.loadUrl(uri)
    }

    /** Load inline HTML, which reports an opaque origin. */
    private fun loadInlineHtml(wv: WebView, html: String) {
        policyFor(wv).enableAboutBlank()
        wv.loadData(html, "text/html", "UTF-8")
    }

    /**
     * Forward a page message to the app only when its source origin is allowed.
     * Called from the web message listener on the main thread.
     */
    internal fun handleWebMessage(wv: WebView, data: String?, sourceOrigin: String, isMainFrame: Boolean) {
        val message = data ?: return
        if (!policyFor(wv).isWebMessageAllowed(sourceOrigin, isMainFrame)) {
            logBlocked("Dropped VWebView message from non-allowlisted origin: $sourceOrigin (mainFrame=$isMainFrame)")
            return
        }
        messageHandlers[wv]?.invoke(mapOf("data" to message))
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

    private fun warnLegacyBridgeOnce() {
        if (legacyBridgeWarned.compareAndSet(false, true)) {
            Log.w(
                TAG,
                "WebView message listener unsupported; using the legacy JavaScript bridge, " +
                    "which only checks the main frame. Update the Android System WebView."
            )
        }
    }

    companion object {
        private const val TAG = "VueNative-WebView"

        /** Name of the `window` object the page posts to. */
        private const val BRIDGE_NAME = "vueNative"

        private val legacyBridgeWarned = AtomicBoolean(false)

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
