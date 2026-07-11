package com.vuenative.core

import android.content.Context
import android.net.Uri
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockk
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VWebViewFactoryTest {
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
    fun removingLoadListenerKeepsErrorListenerAndNormalizesPayload() {
        var loadCount = 0
        var errorCount = 0
        var errorPayload: Map<*, *>? = null
        factory.addEventListener(webView, "load") { loadCount += 1 }
        factory.addEventListener(webView, "error") { payload ->
            errorCount += 1
            errorPayload = payload as? Map<*, *>
        }

        factory.removeEventListener(webView, "load")
        val webViewClient = shadowOf(webView).webViewClient
        webViewClient.onPageFinished(webView, "https://example.com/finished")

        val request = mockk<WebResourceRequest>(relaxed = true)
        every { request.url } returns Uri.parse("https://example.com/failed")
        every { request.isForMainFrame } returns true
        val error = mockk<WebResourceError>(relaxed = true)
        every { error.description } returns "Connection refused"
        webViewClient.onReceivedError(webView, request, error)
        @Suppress("DEPRECATION")
        webViewClient.onReceivedError(
            webView,
            -2,
            "Legacy duplicate",
            "https://example.com/duplicate"
        )

        assertEquals(0, loadCount)
        assertEquals(1, errorCount)
        assertEquals(
            mapOf(
                "message" to "Connection refused",
                "url" to "https://example.com/failed"
            ),
            errorPayload
        )
    }

    @Test
    fun subresourceErrorsDoNotEmitPageLoadErrors() {
        var errorCount = 0
        factory.addEventListener(webView, "error") { errorCount += 1 }

        val request = mockk<WebResourceRequest>(relaxed = true)
        every { request.url } returns Uri.parse("https://example.com/missing-image.png")
        every { request.isForMainFrame } returns false
        val error = mockk<WebResourceError>(relaxed = true)
        every { error.description } returns "Image failed"

        shadowOf(webView).webViewClient.onReceivedError(webView, request, error)

        assertEquals(0, errorCount)
    }

    @Test
    @Config(sdk = [22])
    @Suppress("DEPRECATION")
    fun legacyErrorCallbackUsesNormalizedPayloadOnApi22() {
        var errorPayload: Map<*, *>? = null
        factory.addEventListener(webView, "error") { payload ->
            errorPayload = payload as? Map<*, *>
        }

        shadowOf(webView).webViewClient.onReceivedError(
            webView,
            -2,
            "Host lookup failed",
            "https://example.com/legacy"
        )

        assertEquals(
            mapOf(
                "message" to "Host lookup failed",
                "url" to "https://example.com/legacy"
            ),
            errorPayload
        )
    }

    @Test
    fun javaScriptEnabledCanBeToggled() {
        assertTrue(webView.settings.javaScriptEnabled)
        assertEquals(WebSettings.MIXED_CONTENT_NEVER_ALLOW, webView.settings.mixedContentMode)

        factory.updateProp(webView, "javaScriptEnabled", false)
        assertFalse(webView.settings.javaScriptEnabled)

        factory.updateProp(webView, "javaScriptEnabled", true)
        assertTrue(webView.settings.javaScriptEnabled)
    }
}
