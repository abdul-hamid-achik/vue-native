package com.vuenative.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit tests for [WebViewOriginPolicy] — the regression tests for P1-4.
 *
 * The policy holds no view state so it can be tested without a live WebView, but
 * it parses with `android.net.Uri`, which needs Robolectric. The factory wiring
 * is exercised by [VWebViewFactoryTest].
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WebViewOriginPolicyTest {

    // -- Scheme blocking --

    @Test
    fun blocksDangerousSchemesEvenForAnExplicitSourceLoad() {
        val policy = WebViewOriginPolicy()
        for (uri in listOf(
            "javascript:alert(1)",
            "file:///etc/passwd",
            "data:text/html,<script>alert(1)</script>",
            "content://com.example/secret",
            "blob:https://example.com/uuid",
            "intent://scan/#Intent;scheme=zxing;end",
        )) {
            assertFalse(
                "$uri must never be loadable, not even as the app's own source",
                policy.isNavigationAllowed(uri, isExplicitSourceLoad = true),
            )
            assertFalse(policy.isNavigationAllowed(uri, isExplicitSourceLoad = false))
        }
    }

    @Test
    fun blocksNullAndBlankUri() {
        val policy = WebViewOriginPolicy()
        assertFalse(policy.isNavigationAllowed(null, isExplicitSourceLoad = true))
        assertFalse(policy.isNavigationAllowed("", isExplicitSourceLoad = true))
        assertFalse(policy.isNavigationAllowed("   ", isExplicitSourceLoad = true))
    }

    // -- Default-deny until the app declares content --

    @Test
    fun defaultsToDenyingEveryRemoteNavigation() {
        val policy = WebViewOriginPolicy()
        assertFalse(policy.isNavigationAllowed("https://example.com/", isExplicitSourceLoad = false))
        assertFalse(policy.isNavigationAllowed("http://localhost:8080/", isExplicitSourceLoad = false))
    }

    @Test
    fun allowsTheExplicitSourceUriAndAllowlistsItsOrigin() {
        val policy = WebViewOriginPolicy()
        assertTrue(policy.isNavigationAllowed("https://app.example.com/page", isExplicitSourceLoad = true))

        // Before the app records the origin, subsequent navigations are refused.
        assertFalse(policy.isNavigationAllowed("https://app.example.com/page", isExplicitSourceLoad = false))

        // This is what the factory does when applying the `source` prop.
        policy.allowOrigin("https://app.example.com/page")
        assertTrue(policy.isNavigationAllowed("https://app.example.com/other", isExplicitSourceLoad = false))
        assertTrue(policy.isMessageOriginAllowed("https://app.example.com/other"))
    }

    @Test
    fun allowlistingOneOriginDoesNotAllowAnother() {
        val policy = WebViewOriginPolicy()
        policy.allowOrigin("https://app.example.com/")
        assertFalse(policy.isNavigationAllowed("https://evil.example.com/", isExplicitSourceLoad = false))
        assertFalse(policy.isMessageOriginAllowed("https://evil.example.com/"))
        // A different port is a different origin.
        assertFalse(policy.isNavigationAllowed("https://app.example.com:8443/", isExplicitSourceLoad = false))
    }

    @Test
    fun allowOriginIgnoresNonHttpSchemes() {
        val policy = WebViewOriginPolicy()
        policy.allowOrigin("file:///etc/passwd")
        policy.allowOrigin("javascript:alert(1)")
        assertTrue(policy.allowedOrigins.isEmpty())
    }

    // -- Origin normalisation --

    @Test
    fun normalisesSchemeHostCaseAndDefaultPorts() {
        assertEquals("https://example.com", WebViewOriginPolicy.originOf("HTTPS://EXAMPLE.COM/path?q=1"))
        assertEquals("https://example.com", WebViewOriginPolicy.originOf("https://example.com:443/"))
        assertEquals("http://example.com", WebViewOriginPolicy.originOf("http://example.com:80/"))
        assertEquals("http://localhost:8080", WebViewOriginPolicy.originOf("http://localhost:8080/x"))
        assertEquals(WebViewOriginPolicy.ABOUT_BLANK_ORIGIN, WebViewOriginPolicy.originOf("about:blank"))
        assertNull(WebViewOriginPolicy.originOf("file:///etc/passwd"))
        assertNull(WebViewOriginPolicy.originOf("not a uri at all"))
        assertNull(WebViewOriginPolicy.originOf(null))
    }

    @Test
    fun httpsAndHttpOnTheSameHostAreDifferentOrigins() {
        val policy = WebViewOriginPolicy()
        policy.allowOrigin("https://example.com/")
        assertFalse(policy.isNavigationAllowed("http://example.com/", isExplicitSourceLoad = false))
    }

    // -- allowedOrigins prop --

    @Test
    fun replaceAllowedOriginsOverwritesTheDerivedDefault() {
        val policy = WebViewOriginPolicy()
        policy.allowOrigin("https://app.example.com/")

        policy.replaceAllowedOrigins(listOf("https://cdn.example.com", "https://other.example.com/"))

        assertFalse(policy.isNavigationAllowed("https://app.example.com/", isExplicitSourceLoad = false))
        assertTrue(policy.isNavigationAllowed("https://cdn.example.com/x", isExplicitSourceLoad = false))
        assertTrue(policy.isNavigationAllowed("https://other.example.com/x", isExplicitSourceLoad = false))
        assertTrue(policy.isMessageOriginAllowed("https://cdn.example.com/x"))
    }

    @Test
    fun replaceAllowedOriginsDropsUnusableEntries() {
        val policy = WebViewOriginPolicy()
        policy.replaceAllowedOrigins(listOf("https://ok.example.com", "javascript:alert(1)", "", "nonsense"))
        assertEquals(setOf("https://ok.example.com"), policy.allowedOrigins)
    }

    // -- Inline HTML --

    @Test
    fun inlineHtmlIsOpaqueUntilTheAppLoadsIt() {
        val policy = WebViewOriginPolicy()
        assertFalse(policy.allowsAboutBlank)
        assertFalse(policy.isMessageOriginAllowed(null))
        assertFalse(policy.isMessageOriginAllowed("about:blank"))
        assertFalse(policy.isNavigationAllowed("about:blank", isExplicitSourceLoad = false))

        policy.enableAboutBlank()

        assertTrue(policy.allowsAboutBlank)
        assertTrue(policy.isNavigationAllowed("about:blank", isExplicitSourceLoad = false))
        assertTrue(policy.isMessageOriginAllowed(null))
        assertTrue(policy.isMessageOriginAllowed("about:blank"))
        // `loadData` reports a data: URL as the main-frame URL.
        assertTrue(policy.isMessageOriginAllowed("data:text/html;charset=UTF-8,%3Ch1%3Ehi%3C%2Fh1%3E"))
    }

    @Test
    fun inlineHtmlDoesNotAllowRemoteOrigins() {
        val policy = WebViewOriginPolicy()
        policy.enableAboutBlank()
        assertFalse(policy.isNavigationAllowed("https://evil.example.com/", isExplicitSourceLoad = false))
        assertFalse(policy.isMessageOriginAllowed("https://evil.example.com/"))
    }

    // -- Factory prop parsing --

    @Test
    fun originValuesAcceptsListsArraysAndCommaSeparatedStrings() {
        assertEquals(
            listOf("https://a.example", "https://b.example"),
            VWebViewFactory.originValues(listOf("https://a.example", "https://b.example")),
        )
        assertEquals(
            listOf("https://a.example"),
            VWebViewFactory.originValues(arrayOf<Any?>("https://a.example", null)),
        )
        assertEquals(
            listOf("https://a.example", "https://b.example"),
            VWebViewFactory.originValues("https://a.example, https://b.example"),
        )
        assertEquals(emptyList<String>(), VWebViewFactory.originValues(null))
        assertEquals(emptyList<String>(), VWebViewFactory.originValues(42))
    }
}
