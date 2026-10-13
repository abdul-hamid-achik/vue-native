package com.vuenative.core

import io.mockk.every
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
            storedPinner("api.example.com").check("api.example.com", chainWithKey("any-key".toByteArray()))
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

    @Test
    fun aHostPinnedOnlyWithLegacySha1PinsKeepsWorking() {
        val spki = "legacy-spki".toByteArray()
        val sha1Pin = "sha1/" + java.util.Base64.getEncoder().encodeToString(
            java.security.MessageDigest.getInstance("SHA-1").digest(spki),
        )
        HttpModule.configurePins(mapOf("legacy.example.com" to listOf(sha1Pin)))

        assertEquals(listOf(sha1Pin), HttpModule.pinsFor("legacy.example.com"))
        // Must pass: the 0.23.0 regression stored a refuse-all pin here instead.
        storedPinner("legacy.example.com").check("legacy.example.com", chainWithKey(spki))
        assertThrows(SSLPeerUnverifiedException::class.java) {
            storedPinner("legacy.example.com").check("legacy.example.com", chainWithKey("other".toByteArray()))
        }
    }

    @Test
    fun malformedSha1PinsAreStillRefused() {
        HttpModule.configurePins(mapOf("api.example.com" to listOf("sha1/", "sha1/%%%")))

        assertThrows(SSLPeerUnverifiedException::class.java) {
            storedPinner("api.example.com").check("api.example.com", chainWithKey("any-key".toByteArray()))
        }
    }

    /**
     * A pinner built from the module's stored pins, without the client's chain
     * cleaner. The shared client cleans the chain against the system trust store
     * before it compares pins, so a mocked chain fails there whatever the pins are.
     */
    private fun storedPinner(host: String): okhttp3.CertificatePinner {
        val builder = okhttp3.CertificatePinner.Builder()
        HttpModule.pinsFor(host).orEmpty().forEach { builder.add(host, it) }
        return builder.build()
    }

    private fun chainWithKey(encoded: ByteArray): List<java.security.cert.Certificate> {
        val key = mockk<java.security.PublicKey> { every { this@mockk.encoded } returns encoded }
        return listOf(mockk<X509Certificate>(relaxed = true) { every { publicKey } returns key })
    }
}
