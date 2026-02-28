package com.vuenative.core

import android.os.Looper
import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class EventThrottleTest {

    private val firedPayloads = mutableListOf<Any?>()

    @Before
    fun setUp() {
        firedPayloads.clear()
    }

    private fun flush() {
        Shadows.shadowOf(Looper.getMainLooper()).idle()
    }

    /**
     * Resets lastFireTime to a very old value via reflection so that
     * the first fire() call sees elapsed >= intervalMs.
     * This is needed because Robolectric's SystemClock.uptimeMillis()
     * returns 0 and lastFireTime starts at 0, so elapsed=0 < intervalMs.
     */
    private fun ensureFirstFireImmediate(throttle: EventThrottle) {
        val field = EventThrottle::class.java.getDeclaredField("lastFireTime")
        field.isAccessible = true
        field.setLong(throttle, -100_000L)
    }

    // -------------------------------------------------------------------------
    // Initialization
    // -------------------------------------------------------------------------

    @Test
    fun testCreation() {
        val throttle = EventThrottle(intervalMs = 100L) { firedPayloads.add(it) }
        // Should not fire anything on creation
        assertEquals(0, firedPayloads.size)
        throttle.cancel()
    }

    // -------------------------------------------------------------------------
    // First event fires immediately
    // -------------------------------------------------------------------------

    @Test
    fun testFirstEventFiresImmediately() {
        val throttle = EventThrottle(intervalMs = 100L) { firedPayloads.add(it) }
        ensureFirstFireImmediate(throttle)

        throttle.fire("first")

        assertEquals("First event should fire immediately", 1, firedPayloads.size)
        assertEquals("first", firedPayloads[0])
        throttle.cancel()
    }

    // -------------------------------------------------------------------------
    // Events within window are throttled (trailing fires after delay)
    // -------------------------------------------------------------------------

    @Test
    fun testEventsWithinWindowAreThrottled() {
        val throttle = EventThrottle(intervalMs = 5000L) { firedPayloads.add(it) }
        ensureFirstFireImmediate(throttle)

        // First fires immediately
        throttle.fire("first")
        assertEquals(1, firedPayloads.size)

        // Second should be throttled (within the 5000ms window)
        throttle.fire("second")
        assertEquals("Second event should be throttled", 1, firedPayloads.size)

        // Third should update the pending payload but not fire
        throttle.fire("third")
        assertEquals("Third event should still be throttled", 1, firedPayloads.size)

        // Advance the looper clock past the interval to let the trailing callback fire
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(6000))

        assertEquals("Trailing event should fire with latest payload", 2, firedPayloads.size)
        assertEquals("third", firedPayloads[1])
        throttle.cancel()
    }

    // -------------------------------------------------------------------------
    // Cancel stops pending trailing call
    // -------------------------------------------------------------------------

    @Test
    fun testCancelStopsPendingTrailing() {
        val throttle = EventThrottle(intervalMs = 5000L) { firedPayloads.add(it) }
        ensureFirstFireImmediate(throttle)

        // First fires immediately
        throttle.fire("first")
        assertEquals(1, firedPayloads.size)

        // Second is throttled (trailing scheduled)
        throttle.fire("second")
        assertEquals(1, firedPayloads.size)

        // Cancel before trailing fires
        throttle.cancel()
        flush()

        assertEquals("Trailing should NOT fire after cancel", 1, firedPayloads.size)
    }

    // -------------------------------------------------------------------------
    // Multiple fires with cancel in between
    // -------------------------------------------------------------------------

    @Test
    fun testFireAfterCancel() {
        val throttle = EventThrottle(intervalMs = 5000L) { firedPayloads.add(it) }
        ensureFirstFireImmediate(throttle)

        throttle.fire("first")
        assertEquals(1, firedPayloads.size)

        throttle.fire("second")
        throttle.cancel()
        flush()

        assertEquals("Only the first event should have fired", 1, firedPayloads.size)
    }

    // -------------------------------------------------------------------------
    // Payload is passed correctly
    // -------------------------------------------------------------------------

    @Test
    fun testPayloadPassedCorrectly() {
        val throttle = EventThrottle(intervalMs = 5000L) { firedPayloads.add(it) }
        ensureFirstFireImmediate(throttle)

        val payload = mapOf("x" to 10, "y" to 20)
        throttle.fire(payload)

        assertEquals(1, firedPayloads.size)
        @Suppress("UNCHECKED_CAST")
        val received = firedPayloads[0] as Map<String, Int>
        assertEquals(10, received["x"])
        assertEquals(20, received["y"])
        throttle.cancel()
    }

    // -------------------------------------------------------------------------
    // Null payload is valid
    // -------------------------------------------------------------------------

    @Test
    fun testNullPayload() {
        val throttle = EventThrottle(intervalMs = 5000L) { firedPayloads.add(it) }
        ensureFirstFireImmediate(throttle)

        throttle.fire(null)

        assertEquals(1, firedPayloads.size)
        assertEquals(null, firedPayloads[0])
        throttle.cancel()
    }

    // -------------------------------------------------------------------------
    // Default interval is 16ms
    // -------------------------------------------------------------------------

    @Test
    fun testDefaultInterval() {
        val throttle = EventThrottle { firedPayloads.add(it) }
        ensureFirstFireImmediate(throttle)
        throttle.fire("test")
        assertEquals(1, firedPayloads.size)
        throttle.cancel()
    }

    // -------------------------------------------------------------------------
    // Multiple cancel calls don't crash
    // -------------------------------------------------------------------------

    @Test
    fun testMultipleCancelCalls() {
        val throttle = EventThrottle(intervalMs = 100L) { firedPayloads.add(it) }
        throttle.cancel()
        throttle.cancel()
        throttle.cancel()
        // Should not crash
        assertTrue(true)
    }
}
