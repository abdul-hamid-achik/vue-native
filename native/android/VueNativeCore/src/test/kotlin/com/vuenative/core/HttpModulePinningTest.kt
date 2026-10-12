package com.vuenative.core

import io.mockk.mockk
import java.security.cert.X509Certificate
import javax.net.ssl.SSLPeerUnverifiedException
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class HttpModulePinningTest {

    @Before
    @After
    fun resetPins() {
        HttpModule.resetPins()
    }

    @Test
    fun configurePinsMergesHostsInsteadOfReplacing() {
        HttpModule.configurePins(mapOf("api.example.com" to listOf("sha256/AAA=")))
        HttpModule.configurePins(mapOf("cdn.example.com" to listOf("sha256/BBB=")))

        assertEquals(
            setOf("api.example.com", "cdn.example.com"),
            HttpModule.pinnedHosts(),
        )
    }

    @Test
    fun emptyPinListRemovesAHost() {
        HttpModule.configurePins(
            mapOf(
                "api.example.com" to listOf("sha256/AAA="),
                "cdn.example.com" to listOf("sha256/BBB="),
            ),
        )
        HttpModule.configurePins(mapOf("api.example.com" to emptyList()))

        assertEquals(setOf("cdn.example.com"), HttpModule.pinnedHosts())
        assertFalse(HttpModule.pinnedHosts().contains("api.example.com"))
    }

    @Test
    fun otaAndFileSystemUseTheSharedClient() {
        HttpModule.configurePins(mapOf("updates.example.com" to listOf("sha256/CCC=")))
        val shared = HttpModule.client()
        assertTrue(shared === HttpModule.client())
    }

    @Test
    fun aHostWithOnlyMalformedPinsIsRefusedInsteadOfUnpinned() {
        HttpModule.configurePins(mapOf("api.example.com" to listOf("md5/abc", "not-a-pin")))

        assertTrue(HttpModule.pinnedHosts().contains("api.example.com"))
        assertThrows(SSLPeerUnverifiedException::class.java) {
            HttpModule.client().certificatePinner.check("api.example.com", unmatchedChain())
        }
    }

    @Test
    fun anEmptyPinListStillUnpinsARefusedHost() {
        HttpModule.configurePins(mapOf("api.example.com" to listOf("not-a-pin")))
        HttpModule.configurePins(mapOf("api.example.com" to emptyList()))

        assertFalse(HttpModule.pinnedHosts().contains("api.example.com"))
        HttpModule.client().certificatePinner.check("api.example.com", emptyList())
    }

    @Test
    fun malformedPinsKeepTheHostsPreviousPins() {
        HttpModule.configurePins(mapOf("api.example.com" to listOf("sha256/AAA=")))
        HttpModule.configurePins(mapOf("api.example.com" to listOf("bogus")))

        assertEquals(listOf("sha256/AAA="), HttpModule.pinsFor("api.example.com"))
    }

    @Test
    fun malformedPinsAreDroppedFromAListThatHasAValidPin() {
        HttpModule.configurePins(mapOf("api.example.com" to listOf("bogus", "sha256/AAA=")))

        assertEquals(listOf("sha256/AAA="), HttpModule.pinsFor("api.example.com"))
    }

    /** A peer chain whose key cannot match any pin. Its key material is not needed to fail the check. */
    private fun unmatchedChain() = listOf<java.security.cert.Certificate>(mockk<X509Certificate>(relaxed = true))
}
