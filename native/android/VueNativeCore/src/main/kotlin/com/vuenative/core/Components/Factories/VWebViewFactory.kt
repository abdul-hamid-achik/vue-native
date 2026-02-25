package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONObject

class VWebViewFactory : NativeComponentFactory {
    private val loadHandlers = mutableMapOf<WebView, (Any?) -> Unit>()
    private val errorHandlers = mutableMapOf<WebView, (Any?) -> Unit>()
    private val messageHandlers = mutableMapOf<WebView, (Any?) -> Unit>()

    override fun createView(context: Context): View {
        return WebView(context).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView, url: String) {
                    loadHandlers[view]?.invoke(mapOf("url" to url))
                }
                override fun onReceivedError(view: WebView, req: WebResourceRequest, err: WebResourceError) {
                    errorHandlers[view]?.invoke(mapOf(
                        "url" to (req.url?.toString() ?: ""),
                        "description" to (if (android.os.Build.VERSION.SDK_INT >= 23) err.description.toString() else "Error")
                    ))
                }
            }
            webChromeClient = WebChromeClient()
            // JavaScript bridge for message passing
            addJavascriptInterface(object {
                @android.webkit.JavascriptInterface
                fun postMessage(msg: String) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        messageHandlers[this@apply]?.invoke(mapOf("data" to msg))
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
                    uri != null && uri.isNotEmpty() -> wv.loadUrl(uri)
                    html != null && html.isNotEmpty() -> wv.loadData(html, "text/html", "UTF-8")
                }
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
        loadHandlers.remove(wv)
        errorHandlers.remove(wv)
        messageHandlers.remove(wv)
    }
}
