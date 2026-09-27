package com.vuenative.core

import android.net.Uri

/**
 * Origin allowlist policy for `VWebView`.
 *
 * ## Why this exists
 *
 * `VWebView` runs remote content with `javaScriptEnabled = true` and exposes a
 * `vueNative` JavaScript interface whose `postMessage` lands directly in the Vue
 * app's event stream. Without an origin check, ANY page the view ends up
 * displaying — reached by a redirect, a link, `window.open`, or an injected
 * `location` assignment — can post arbitrary payloads into app logic that then
 * typically calls FileSystem or SecureStorage. Loading `file://` and
 * `javascript:` URIs was also possible.
 *
 * ## Default behaviour
 *
 * Safe with zero configuration: the allowlist starts empty and is seeded with
 * the origin of the URI the app itself passed to the `source` prop, or with
 * `about:blank` when the app passed inline `html`. Everything else is refused.
 * A host that needs more origins sets the `allowedOrigins` prop, which REPLACES
 * the derived default rather than extending it.
 *
 * ## Known limitation vs. WebKit
 *
 * `WebView.getUrl()` reports the MAIN frame URL, so a cross-origin iframe nested
 * inside an allowlisted page is not distinguishable here. `WKScriptMessage`
 * carries `frameInfo.securityOrigin`, so the Apple implementations can enforce
 * per-frame. Navigation blocking still prevents the main frame from moving to a
 * non-allowlisted origin.
 */
class WebViewOriginPolicy {

    companion object {
        /** Canonical origin string for content loaded inline via `loadData`. */
        const val ABOUT_BLANK_ORIGIN = "about:blank"

        /** Build a canonical `scheme://host[:port]` origin from a URI string. */
        fun originOf(uri: String?): String? {
            val trimmed = uri?.trim()
            if (trimmed.isNullOrEmpty()) return null
            val parsed = try {
                Uri.parse(trimmed)
            } catch (e: Exception) {
                return null
            }
            return originOf(parsed.scheme, parsed.host, parsed.port)
        }

        /**
         * Build a canonical origin from its parts. Returns null for any scheme
         * other than http, https and about.
         */
        fun originOf(scheme: String?, host: String?, port: Int): String? {
            val loweredScheme = scheme?.lowercase() ?: return null
            if (loweredScheme == "about") return ABOUT_BLANK_ORIGIN
            if (loweredScheme != "http" && loweredScheme != "https") return null
            val loweredHost = host?.lowercase()
            if (loweredHost.isNullOrEmpty()) return null
            // Android reports port -1 when the URI omits it; treat that and 0 as
            // "no explicit port" so `https://x` and `https://x:443` match.
            val isDefaultPort = port <= 0 || port == defaultPort(loweredScheme)
            return if (isDefaultPort) {
                "$loweredScheme://$loweredHost"
            } else {
                "$loweredScheme://$loweredHost:$port"
            }
        }

        /** Normalise a host-supplied allowlist entry, dropping anything unusable. */
        fun normalise(originString: String): String? = originOf(originString)

        private fun defaultPort(scheme: String): Int = if (scheme == "https") 443 else 80
    }

    var allowedOrigins: MutableSet<String> = mutableSetOf()
        private set

    /** Set when the app loaded inline HTML, which reports an opaque origin. */
    var allowsAboutBlank: Boolean = false
        private set

    /**
     * Record the origin of an explicitly requested source URI. Only http(s)
     * origins are recorded — an `about:` or `file:` source never widens the
     * message allowlist.
     */
    fun allowOrigin(uri: String) {
        val origin = originOf(uri) ?: return
        if (origin != ABOUT_BLANK_ORIGIN) {
            allowedOrigins.add(origin)
        }
    }

    /** Permit content loaded inline via `loadData`. */
    fun enableAboutBlank() {
        allowsAboutBlank = true
    }

    /** Replace the allowlist with host-supplied origins. */
    fun replaceAllowedOrigins(values: List<String>) {
        allowedOrigins = values.mapNotNull { normalise(it) }.toMutableSet()
    }

    /**
     * Whether a navigation to [uri] may proceed.
     *
     * @param isExplicitSourceLoad `true` only for the URI the app passed through
     *   the `source` prop. That bypasses the ORIGIN check — the app's own
     *   declared content is trusted to that extent — but never the SCHEME check,
     *   so `javascript:` and `file:` sources are still refused.
     */
    fun isNavigationAllowed(uri: String?, isExplicitSourceLoad: Boolean): Boolean {
        val trimmed = uri?.trim()
        if (trimmed.isNullOrEmpty()) return false
        val parsed = try {
            Uri.parse(trimmed)
        } catch (e: Exception) {
            return false
        }
        val scheme = parsed.scheme?.lowercase() ?: return false
        if (scheme == "about") return allowsAboutBlank
        if (scheme != "http" && scheme != "https") return false
        if (isExplicitSourceLoad) return true
        val origin = originOf(parsed.scheme, parsed.host, parsed.port) ?: return false
        return allowedOrigins.contains(origin)
    }

    /**
     * Whether a `postMessage` from the current main-frame URL may be forwarded
     * to JavaScript. See the class doc for the main-frame limitation.
     */
    fun isMessageOriginAllowed(currentUrl: String?): Boolean {
        val trimmed = currentUrl?.trim()
        if (trimmed.isNullOrEmpty() || trimmed.startsWith("about:")) return allowsAboutBlank
        // `loadData` reports a `data:` URL. Only the app's own inline HTML sets
        // [allowsAboutBlank], so this cannot be reached by remote content.
        if (trimmed.startsWith("data:")) return allowsAboutBlank
        val origin = originOf(trimmed) ?: return allowsAboutBlank
        return allowedOrigins.contains(origin)
    }
}
