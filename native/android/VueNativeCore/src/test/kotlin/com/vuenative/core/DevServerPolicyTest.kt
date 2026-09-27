package com.vuenative.core

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pure-JVM coverage for the hot-reload dev-server URL gate. No Robolectric:
 * [DevServerPolicy] deliberately has no Android dependencies so the policy can
 * be tested in isolation from [VueNativeActivity].
 */
class DevServerPolicyTest {

    @Test
    fun allowsLoopbackAddresses() {
        assertEquals(DevServerPolicy.Verdict.ALLOWED, DevServerPolicy.evaluate("ws://127.0.0.1:5173"))
        assertEquals(DevServerPolicy.Verdict.ALLOWED, DevServerPolicy.evaluate("ws://localhost:5173"))
        assertEquals(DevServerPolicy.Verdict.ALLOWED, DevServerPolicy.evaluate("ws://127.5.5.5:5173"))
        assertEquals(DevServerPolicy.Verdict.ALLOWED, DevServerPolicy.evaluate("ws://[::1]:5173"))
    }

    @Test
    fun allowsPrivateAndLinkLocalAddresses() {
        // The Android emulator aliases the host machine's loopback as 10.0.2.2.
        assertEquals(DevServerPolicy.Verdict.ALLOWED, DevServerPolicy.evaluate("ws://10.0.2.2:5173"))
        assertEquals(DevServerPolicy.Verdict.ALLOWED, DevServerPolicy.evaluate("ws://10.20.30.40:5173"))
        assertEquals(DevServerPolicy.Verdict.ALLOWED, DevServerPolicy.evaluate("ws://192.168.1.25:5173"))
        assertEquals(DevServerPolicy.Verdict.ALLOWED, DevServerPolicy.evaluate("ws://172.16.0.9:5173"))
        assertEquals(DevServerPolicy.Verdict.ALLOWED, DevServerPolicy.evaluate("ws://172.31.255.1:5173"))
        assertEquals(DevServerPolicy.Verdict.ALLOWED, DevServerPolicy.evaluate("ws://169.254.1.1:5173"))
    }

    @Test
    fun rejectsPublicIpLiterals() {
        // A release-or-debug build pointed at a public address is never an
        // intentional dev server, and hot reload evaluates whatever JS arrives.
        assertEquals(
            DevServerPolicy.Verdict.REJECTED_PUBLIC_ADDRESS,
            DevServerPolicy.evaluate("ws://8.8.8.8:5173"),
        )
        assertEquals(
            DevServerPolicy.Verdict.REJECTED_PUBLIC_ADDRESS,
            DevServerPolicy.evaluate("ws://172.32.0.1:5173"),
        )
        assertEquals(
            DevServerPolicy.Verdict.REJECTED_PUBLIC_ADDRESS,
            DevServerPolicy.evaluate("ws://[2001:db8::1]:5173"),
        )
    }

    @Test
    fun allowsHostnamesButFlagsThemAsUnverified() {
        // `vue-native dev --lan` is commonly reached by machine name, and a
        // hostname cannot be classified without a DNS lookup.
        assertEquals(
            DevServerPolicy.Verdict.ALLOWED_UNVERIFIED_HOSTNAME,
            DevServerPolicy.evaluate("ws://my-mac.local:5173"),
        )
    }

    @Test
    fun rejectsUnparseableUrls() {
        assertEquals(
            DevServerPolicy.Verdict.REJECTED_UNPARSEABLE,
            DevServerPolicy.evaluate("not a url"),
        )
        assertEquals(DevServerPolicy.Verdict.REJECTED_UNPARSEABLE, DevServerPolicy.evaluate(""))
    }

    @Test
    fun isAllowedMatchesTheVerdicts() {
        assertEquals(true, DevServerPolicy.isAllowed("ws://10.0.2.2:5173"))
        assertEquals(true, DevServerPolicy.isAllowed("ws://my-mac.local:5173"))
        assertEquals(false, DevServerPolicy.isAllowed("ws://8.8.8.8:5173"))
        assertEquals(false, DevServerPolicy.isAllowed("nonsense"))
    }

    /**
     * The debuggable gate is the load-bearing one: without it a release APK
     * following the documented host pattern connected to a plaintext `ws://`
     * endpoint and evaluated whatever JavaScript arrived, with full
     * native-module privileges. iOS gates the same path with `#if DEBUG`.
     */
    @Test
    fun rejectsEveryUrlWhenTheHostIsNotDebuggable() {
        listOf(
            "ws://localhost:5173",
            "ws://127.0.0.1:5173",
            "ws://10.0.2.2:5173",
            "ws://192.168.1.25:5173",
            "ws://my-mac.local:5173",
        ).forEach { url ->
            assertEquals(
                "a non-debuggable build must never hot reload: $url",
                DevServerPolicy.Verdict.REJECTED_NOT_DEBUGGABLE,
                DevServerPolicy.evaluate(url, isHostDebuggable = false),
            )
            assertEquals(false, DevServerPolicy.isAllowed(url, isHostDebuggable = false))
        }
    }

    @Test
    fun debuggableGateIsCheckedBeforeTheUrlIsEvenParsed() {
        assertEquals(
            DevServerPolicy.Verdict.REJECTED_NOT_DEBUGGABLE,
            DevServerPolicy.evaluate("not a url", isHostDebuggable = false),
        )
    }
}
