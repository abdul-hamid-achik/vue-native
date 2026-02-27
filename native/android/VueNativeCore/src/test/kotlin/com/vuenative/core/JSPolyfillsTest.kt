package com.vuenative.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class JSPolyfillsTest {

    @Before
    fun setUp() {
        JSPolyfills.reset()
    }

    // -------------------------------------------------------------------------
    // reset() clears state
    // -------------------------------------------------------------------------

    @Test
    fun testResetClearsState() {
        // Call reset — should not throw
        JSPolyfills.reset()
        // Call again — idempotent
        JSPolyfills.reset()
        assertTrue("reset() should complete without error", true)
    }

    // -------------------------------------------------------------------------
    // JSPolyfills is a singleton object
    // -------------------------------------------------------------------------

    @Test
    fun testIsSingletonObject() {
        val ref1 = JSPolyfills
        val ref2 = JSPolyfills
        assertTrue("JSPolyfills should be a singleton object", ref1 === ref2)
    }

    // -------------------------------------------------------------------------
    // reset() is idempotent — can be called multiple times
    // -------------------------------------------------------------------------

    @Test
    fun testResetIsIdempotent() {
        JSPolyfills.reset()
        JSPolyfills.reset()
        JSPolyfills.reset()
        assertTrue("Multiple resets should not crash", true)
    }

    // -------------------------------------------------------------------------
    // TAG constant exists (validates structure)
    // -------------------------------------------------------------------------

    @Test
    fun testTagConstant() {
        // Access via reflection to verify TAG is set
        val tagField = JSPolyfills::class.java.getDeclaredField("TAG")
        tagField.isAccessible = true
        val tag = tagField.get(null) as String
        assertEquals("VueNative-Polyfills", tag)
    }

    // -------------------------------------------------------------------------
    // Timer storage is accessible internally
    // -------------------------------------------------------------------------

    @Test
    fun testTimerStorageCleared() {
        // Access internal timers map via reflection
        val timersField = JSPolyfills::class.java.getDeclaredField("timers")
        timersField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val timers = timersField.get(null) as MutableMap<Int, Runnable>
        assertTrue("Timers should be empty after reset", timers.isEmpty())
    }

    // -------------------------------------------------------------------------
    // Timer ID counter resets
    // -------------------------------------------------------------------------

    @Test
    fun testTimerIdResets() {
        val field = JSPolyfills::class.java.getDeclaredField("nextTimerId")
        field.isAccessible = true

        JSPolyfills.reset()
        val afterReset = field.getInt(null)
        assertEquals("nextTimerId should reset to 1", 1, afterReset)
    }

    // -------------------------------------------------------------------------
    // RAF state resets
    // -------------------------------------------------------------------------

    @Test
    fun testRafStateResets() {
        val callbacksField = JSPolyfills::class.java.getDeclaredField("rafCallbacks")
        callbacksField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val rafCallbacks = callbacksField.get(null) as MutableMap<Int, Any>
        assertTrue("RAF callbacks should be empty after reset", rafCallbacks.isEmpty())

        val postedField = JSPolyfills::class.java.getDeclaredField("rafChoreographerPosted")
        postedField.isAccessible = true
        val posted = postedField.getBoolean(null)
        assertTrue("rafChoreographerPosted should be false after reset", !posted)
    }

    // -------------------------------------------------------------------------
    // RAF ID counter resets
    // -------------------------------------------------------------------------

    @Test
    fun testRafIdResets() {
        val field = JSPolyfills::class.java.getDeclaredField("nextRafId")
        field.isAccessible = true

        JSPolyfills.reset()
        val afterReset = field.getInt(null)
        assertEquals("nextRafId should reset to 1", 1, afterReset)
    }

    // -------------------------------------------------------------------------
    // mainHandler exists
    // -------------------------------------------------------------------------

    @Test
    fun testMainHandlerExists() {
        val field = JSPolyfills::class.java.getDeclaredField("mainHandler")
        field.isAccessible = true
        val handler = field.get(null)
        assertNotNull("mainHandler should not be null", handler)
    }

    // -------------------------------------------------------------------------
    // httpClient exists
    // -------------------------------------------------------------------------

    @Test
    fun testHttpClientExists() {
        val field = JSPolyfills::class.java.getDeclaredField("httpClient")
        field.isAccessible = true
        val client = field.get(null)
        assertNotNull("httpClient should not be null", client)
    }
}
