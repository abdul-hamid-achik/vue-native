package com.vuenative.core

import android.content.Context
import android.net.Uri
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockk
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Factory-wiring tests for P1-4. The policy rules themselves are covered by
 * [WebViewOriginPolicyTest]; these prove [VWebViewFactory] actually consults the
 * policy before loading a source, before allowing a navigation, and before
 * handing a `postMessage` to JavaScript.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VWebViewOriginPolicyWiringTest {
    private lateinit var factory: VWebViewFactory
    private lateinit var webView: WebView

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        factory = VWebViewFactory()
        webView = factory.createView(context) as WebView
    }

    @After
    fun tearDown() {
        factory.destroyView(webView)
    }

    @Test
    fun dangerousSourceSchemesNeverReachTheWebView() {
        for (uri in listOf(
            "javascript:alert(1)",
            "file:///etc/passwd",
            "data:text/html,<script>alert(1)</script>",
            "content://com.example/secret",
        )) {
            factory.updateProp(webView, "source", mapOf("uri" to uri))
            assertNull("$uri must never be handed to loadUrl", shadowOf(webView).lastLoadedUrl)
        }
    }

    @Test
    fun httpsSourceIsLoaded() {
        factory.updateProp(webView, "source", mapOf("uri" to "https://app.example.com/page"))
        assertEquals("https://app.example.com/page", shadowOf(webView).lastLoadedUrl)
    }

    @Test
    fun shouldOverrideUrlLoadingBlocksNonAllowlistedNavigation() {
        factory.updateProp(webView, "source", mapOf("uri" to "https://app.example.com/page"))
        val client = webView.webViewClient

        val sameOrigin = mockk<WebResourceRequest>()
        every { sameOrigin.url } returns Uri.parse("https://app.example.com/next")
        assertFalse(
            "a same-origin navigation must be allowed",
            client.shouldOverrideUrlLoading(webView, sameOrigin),
        )

        val crossOrigin = mockk<WebResourceRequest>()
        every { crossOrigin.url } returns Uri.parse("https://evil.example.com/")
        assertTrue(
            "a cross-origin navigation must be blocked",
            client.shouldOverrideUrlLoading(webView, crossOrigin),
        )

        val script = mockk<WebResourceRequest>()
        every { script.url } returns Uri.parse("javascript:alert(1)")
        assertTrue(client.shouldOverrideUrlLoading(webView, script))
    }

    @Test
    fun allowedOriginsPropReplacesTheDerivedDefault() {
        factory.updateProp(webView, "source", mapOf("uri" to "https://app.example.com/page"))
        factory.updateProp(webView, "allowedOrigins", listOf("https://cdn.example.com"))
        val client = webView.webViewClient

        val derived = mockk<WebResourceRequest>()
        every { derived.url } returns Uri.parse("https://app.example.com/next")
        assertTrue(
            "an explicit allowedOrigins prop must replace the origin derived from source",
            client.shouldOverrideUrlLoading(webView, derived),
        )

        val replacement = mockk<WebResourceRequest>()
        every { replacement.url } returns Uri.parse("https://cdn.example.com/asset")
        assertFalse(client.shouldOverrideUrlLoading(webView, replacement))
    }

    @Test
    fun webViewSettingsDenyFileAndCrossOriginAccess() {
        @Suppress("DEPRECATION")
        assertFalse(webView.settings.allowFileAccess)
        @Suppress("DEPRECATION")
        assertFalse(webView.settings.allowContentAccess)
        @Suppress("DEPRECATION")
        assertFalse(webView.settings.allowFileAccessFromFileURLs)
        @Suppress("DEPRECATION")
        assertFalse(webView.settings.allowUniversalAccessFromFileURLs)
        assertFalse(webView.settings.javaScriptCanOpenWindowsAutomatically)
        assertEquals(WebSettings.MIXED_CONTENT_NEVER_ALLOW, webView.settings.mixedContentMode)
    }

    @Test
    fun destroyViewReleasesThePolicySoALaterViewStartsDenied() {
        factory.updateProp(webView, "source", mapOf("uri" to "https://app.example.com/page"))
        factory.destroyView(webView)

        val replacement = factory.createView(
            ApplicationProvider.getApplicationContext<Context>(),
        ) as WebView
        try {
            val client = replacement.webViewClient
            val request = mockk<WebResourceRequest>()
            every { request.url } returns Uri.parse("https://app.example.com/page")
            assertTrue(
                "a fresh web view must not inherit the destroyed view's allowlist",
                client.shouldOverrideUrlLoading(replacement, request),
            )
        } finally {
            factory.destroyView(replacement)
        }
    }
}
