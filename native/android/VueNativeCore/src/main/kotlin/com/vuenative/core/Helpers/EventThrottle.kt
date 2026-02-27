package com.vuenative.core

import android.os.Handler
import android.os.Looper
import android.os.SystemClock

/**
 * Throttles high-frequency event handlers to avoid flooding the JS bridge.
 *
 * When a high-frequency event (scroll, slider drag) fires many times per frame,
 * each invocation becomes a bridge round-trip. This utility ensures at most one
 * call per [intervalMs] milliseconds, with a trailing call to deliver the latest value.
 *
 * Default interval: 16ms (~60 FPS).
 */
class EventThrottle(
    private val intervalMs: Long = 16L,
    private val handler: (Any?) -> Unit
) {
    private var lastFireTime: Long = 0
    private var pendingTrailing = false
    private var latestPayload: Any? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val trailingRunnable = Runnable {
        lastFireTime = SystemClock.uptimeMillis()
        pendingTrailing = false
        handler(latestPayload)
    }

    /**
     * Call this from the native event callback instead of the original handler.
     * Fires immediately if enough time has elapsed, otherwise schedules a trailing call.
     */
    fun fire(payload: Any?) {
        val now = SystemClock.uptimeMillis()
        val elapsed = now - lastFireTime
        latestPayload = payload

        if (elapsed >= intervalMs) {
            lastFireTime = now
            pendingTrailing = false
            mainHandler.removeCallbacks(trailingRunnable)
            handler(payload)
        } else if (!pendingTrailing) {
            pendingTrailing = true
            mainHandler.postDelayed(trailingRunnable, intervalMs - elapsed)
        }
        // If trailing is already pending, latestPayload is updated above
    }

    /** Cancel any pending trailing call. */
    fun cancel() {
        mainHandler.removeCallbacks(trailingRunnable)
        pendingTrailing = false
    }
}
