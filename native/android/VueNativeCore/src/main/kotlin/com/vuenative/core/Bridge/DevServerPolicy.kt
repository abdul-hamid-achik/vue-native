package com.vuenative.core

import java.net.URI

/**
 * Decides whether a hot-reload dev-server URL may be connected to.
 *
 * Hot reload opens a plaintext `ws://` socket and evaluates whatever JavaScript
 * arrives on it with full native-module privileges (file system, camera,
 * secure storage, …). It must therefore never run in a shipping build, and even
 * in a debug build the peer should be the developer's own machine — not an
 * arbitrary host on the internet that happens to answer on the configured port.
 *
 * The debuggability decision itself lives in [VueNativeActivity]; this object
 * only classifies the URL so both can be unit-tested without an Activity.
 */
internal object DevServerPolicy {

    enum class Verdict {
        /** Loopback, link-local or RFC1918 host — always fine. */
        ALLOWED,

        /**
         * A hostname rather than an IP literal. Allowed (dev servers are usually
         * reached as `ws://my-mac.local:5173`), but callers should log it since
         * the address cannot be classified without doing a DNS lookup.
         */
        ALLOWED_UNVERIFIED_HOSTNAME,

        /** The build is not debuggable, so hot reload must never run at all. */
        REJECTED_NOT_DEBUGGABLE,

        /** A public IP literal. Refused: this is never an intentional dev server. */
        REJECTED_PUBLIC_ADDRESS,

        /** The URL could not be parsed or has no host. */
        REJECTED_UNPARSEABLE,
    }

    /**
     * @param isHostDebuggable `ApplicationInfo.FLAG_DEBUGGABLE` on the running
     *   app. Checked first: a release build must never open the socket at all,
     *   whatever URL it was handed.
     */
    fun evaluate(url: String, isHostDebuggable: Boolean = true): Verdict {
        if (!isHostDebuggable) return Verdict.REJECTED_NOT_DEBUGGABLE

        val host = try {
            URI(url).host
        } catch (e: Exception) {
            null
        }
        if (host.isNullOrBlank()) return Verdict.REJECTED_UNPARSEABLE
        if (host.equals("localhost", ignoreCase = true)) return Verdict.ALLOWED

        // java.net.URI keeps the brackets on an IPv6 literal host.
        val literal = host.removePrefix("[").removeSuffix("]")
        if (isLoopbackIpv6(literal) || isLinkLocalIpv6(literal)) return Verdict.ALLOWED
        if (literal.contains(':')) {
            // Some other IPv6 literal — a global unicast address is not a dev box.
            return Verdict.REJECTED_PUBLIC_ADDRESS
        }

        val octets = literal.split('.')
        if (octets.size == 4 && octets.all { it.toIntOrNull() in 0..255 }) {
            return if (isPrivateIpv4(octets.map { it.toInt() })) {
                Verdict.ALLOWED
            } else {
                Verdict.REJECTED_PUBLIC_ADDRESS
            }
        }

        return Verdict.ALLOWED_UNVERIFIED_HOSTNAME
    }

    fun isAllowed(url: String, isHostDebuggable: Boolean = true): Boolean =
        when (evaluate(url, isHostDebuggable)) {
            Verdict.ALLOWED, Verdict.ALLOWED_UNVERIFIED_HOSTNAME -> true
            Verdict.REJECTED_NOT_DEBUGGABLE,
            Verdict.REJECTED_PUBLIC_ADDRESS,
            Verdict.REJECTED_UNPARSEABLE,
            -> false
        }

    private fun isLoopbackIpv6(host: String) = host == "::1" || host.equals("0:0:0:0:0:0:0:1")

    private fun isLinkLocalIpv6(host: String) = host.startsWith("fe8", ignoreCase = true)

    /** 127/8, 10/8, 172.16/12, 192.168/16, 169.254/16 and 0.0.0.0. */
    private fun isPrivateIpv4(octets: List<Int>): Boolean {
        val (a, b) = octets[0] to octets[1]
        return when (a) {
            0, 10, 127 -> true
            172 -> b in 16..31
            192 -> b == 168
            169 -> b == 254
            else -> false
        }
    }
}
