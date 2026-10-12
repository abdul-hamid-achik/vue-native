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
 * Safe with zero configuration: the allowlist is seeded with the origin of the
 * URI the app itself passed to the `source` prop (replaced on every source
 * change), or with `about:blank` when the app passed inline `html`. Everything
 * else is refused. A host that needs more origins sets the `allowedOrigins`
 * prop, which REPLACES the derived default rather than extending it. An empty
 * list restores the derived default, so the prop's position relative to `source`
 * never changes the result.
 *
 * ## Frames
 *
 * Messages arrive through a `WebViewCompat` web message listener, which reports
 * each message's source origin and frame, so [isWebMessageAllowed] checks every
 * frame. Only the legacy `addJavascriptInterface` fallback (used when the listener
 * feature is missing) sees just the main frame's URL, so a cross-origin iframe
 * nested in an allowlisted page cannot be told apart there. Navigation blocking
 * still stops the main frame from moving to a non-allowlisted origin.
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

    /** Origin of the CURRENT source only. Replaced, never accumulated, on every source change. */
    private var derivedOrigins: Set<String> = emptySet()

    /** Origins from the `allowedOrigins` prop. Empty means "use [derivedOrigins]". */
    private var hostOrigins: Set<String> = emptySet()

    /** The effective allowlist: the host prop when set, otherwise the current source's origin. */
    val allowedOrigins: Set<String>
        get() = if (hostOrigins.isNotEmpty()) hostOrigins else derivedOrigins

    /** Set only while the current source is inline HTML, which reports an opaque origin. */
    var allowsAboutBlank: Boolean = false
        private set

    /**
     * Record the origin of the source URI the app requested. The previous source's
     * origin is dropped. An `about:`, `file:` or other non-http(s) source leaves
     * the allowlist empty, so it never widens the message allowlist.
     */
    fun allowOrigin(uri: String) {
        val origin = originOf(uri)
        derivedOrigins = if (origin != null && origin != ABOUT_BLANK_ORIGIN) setOf(origin) else emptySet()
        allowsAboutBlank = false
    }

    /** Record inline content loaded via `loadData`, which replaces any previous source origin. */
    fun enableAboutBlank() {
        derivedOrigins = setOf(ABOUT_BLANK_ORIGIN)
        allowsAboutBlank = true
    }

    /** Set the allowlist from the host-supplied `allowedOrigins` prop. An empty list restores the derived origin. */
    fun replaceAllowedOrigins(values: List<String>) {
        hostOrigins = values.mapNotNull { normalise(it) }.toSet()
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

    /**
     * Whether a page message from [sourceOrigin], sent from a frame that is or is
     * not the main frame, may be forwarded to JavaScript.
     *
     * An opaque origin (`"null"` or empty, as reported for inline content) and
     * `about:blank` are accepted only in the main frame of inline HTML the app
     * loaded. Any other origin must be in the effective allowlist, in any frame.
     */
    fun isWebMessageAllowed(sourceOrigin: String, isMainFrame: Boolean): Boolean {
        val trimmed = sourceOrigin.trim()
        if (trimmed.isEmpty() || trimmed == "null") return allowsAboutBlank && isMainFrame
        val origin = originOf(trimmed) ?: return false
        if (origin == ABOUT_BLANK_ORIGIN) return allowsAboutBlank && isMainFrame
        return allowedOrigins.contains(origin)
    }
}
