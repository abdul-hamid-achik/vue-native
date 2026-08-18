package com.vuenative.core

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
}
