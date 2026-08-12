package com.vuenative.core

import android.os.Looper
import io.mockk.mockk
import io.mockk.verify
import okhttp3.WebSocket
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class HotReloadManagerTest {

    private var lastReloadCode: String? = null
    private lateinit var manager: HotReloadManager

    @Before
    fun setUp() {
        lastReloadCode = null
        manager = HotReloadManager { code ->
            lastReloadCode = code
        }
    }

    // -------------------------------------------------------------------------
    // Initialization
    // -------------------------------------------------------------------------

    @Test
    fun testCreation() {
        assertNotNull("HotReloadManager should be created", manager)
    }

    // -------------------------------------------------------------------------
    // disconnect() clears state and is idempotent
    // -------------------------------------------------------------------------

    @Test
    fun testDisconnectClearsState() {
        manager.connect("ws://localhost:3000")
        manager.disconnect()

        val serverField = HotReloadManager::class.java.getDeclaredField("serverUrl")
        serverField.isAccessible = true
        assertNull("serverUrl should be null after disconnect", serverField.get(manager))

        val wsField = HotReloadManager::class.java.getDeclaredField("webSocket")
        wsField.isAccessible = true
        assertNull("webSocket should be null after disconnect", wsField.get(manager))

        val disconnectedField = HotReloadManager::class.java.getDeclaredField("disconnected")
        disconnectedField.isAccessible = true
        assertTrue("disconnected should be true after disconnect", disconnectedField.getBoolean(manager))
    }

    @Test
    fun testDisconnectIdempotent() {
        manager.disconnect()
        manager.disconnect()
        manager.disconnect()
        // Should not throw
        assertTrue(true)
    }

    // -------------------------------------------------------------------------
    // connect() stores the server URL
    // -------------------------------------------------------------------------

    @Test
    fun testConnectStoresUrl() {
        manager.connect("ws://localhost:3000")

        val serverField = HotReloadManager::class.java.getDeclaredField("serverUrl")
        serverField.isAccessible = true
        assertEquals("ws://localhost:3000", serverField.get(manager))

        manager.disconnect()
    }

    // -------------------------------------------------------------------------
    // httpClient exists
    // -------------------------------------------------------------------------

    @Test
    fun testHttpClientExists() {
        val field = HotReloadManager::class.java.getDeclaredField("httpClient")
        field.isAccessible = true
        assertNotNull("httpClient should not be null", field.get(manager))
    }

    // -------------------------------------------------------------------------
    // Message handling (protocol parity with the dev server / shared Swift impl)
    // -------------------------------------------------------------------------

    private fun invokeHandleMessage(webSocket: WebSocket, text: String) {
        val method = HotReloadManager::class.java.getDeclaredMethod(
            "handleMessage",
            WebSocket::class.java,
            String::class.java,
        )
        method.isAccessible = true
        method.invoke(manager, webSocket, text)
    }

    @Test
    fun testPingRepliesWithPong() {
        val socket = mockk<WebSocket>(relaxed = true)
        invokeHandleMessage(socket, "{\"type\":\"ping\"}")
        verify { socket.send("{\"type\":\"pong\"}") }
    }

    @Test
    fun testBundleMessageTriggersReloadInline() {
        val socket = mockk<WebSocket>(relaxed = true)
        invokeHandleMessage(socket, "{\"type\":\"bundle\",\"bundle\":\"console.log('hi')\"}")

        // onReload is posted to the main handler — flush the main looper.
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals("console.log('hi')", lastReloadCode)
        // The bundle is used inline: no HTTP fetch, so nothing else is sent on the socket.
        verify(exactly = 0) { socket.send(any<String>()) }
    }

    @Test
    fun testEmptyBundleIsIgnored() {
        val socket = mockk<WebSocket>(relaxed = true)
        invokeHandleMessage(socket, "{\"type\":\"bundle\",\"bundle\":\"\"}")
        shadowOf(Looper.getMainLooper()).idle()
        assertNull("Empty bundle must not trigger a reload", lastReloadCode)
    }

    @Test
    fun testConnectedMessageResetsReconnectCounter() {
        val socket = mockk<WebSocket>(relaxed = true)
        val field = HotReloadManager::class.java.getDeclaredField("reconnectAttempts")
        field.isAccessible = true
        field.setInt(manager, 5)

        invokeHandleMessage(socket, "{\"type\":\"connected\"}")

        assertEquals(0, field.getInt(manager))
    }

    @Test
    fun testNonJsonMessageIsIgnored() {
        val socket = mockk<WebSocket>(relaxed = true)
        // Should not throw and should not reload.
        invokeHandleMessage(socket, "full-reload")
        shadowOf(Looper.getMainLooper()).idle()
        assertNull(lastReloadCode)
    }

    // -------------------------------------------------------------------------
    // hotReloadUrl() — auth token query construction
    // -------------------------------------------------------------------------

    @Test
    fun testHotReloadUrlAppendsToken() {
        assertEquals(
            "ws://192.168.1.5:8174?token=abc123",
            HotReloadManager.hotReloadUrl("ws://192.168.1.5:8174", "abc123"),
        )
    }

    @Test
    fun testHotReloadUrlEmptyTokenLeavesUrlUnchanged() {
        assertEquals(
            "ws://localhost:8174",
            HotReloadManager.hotReloadUrl("ws://localhost:8174", ""),
        )
    }

    @Test
    fun testHotReloadUrlUsesAmpersandWhenQueryExists() {
        assertEquals(
            "ws://localhost:8174?foo=bar&token=abc123",
            HotReloadManager.hotReloadUrl("ws://localhost:8174?foo=bar", "abc123"),
        )
    }

    // -------------------------------------------------------------------------
    // reconnectDelay() — exponential backoff capped at 30s, mirroring
    // HotReloadManager.swift's reconnectDelay(forAttempt:).
    // -------------------------------------------------------------------------

    @Test
    fun testReconnectDelayGrowsExponentiallyUpToCap() {
        assertEquals(1_000L, HotReloadManager.reconnectDelay(1))
        assertEquals(2_000L, HotReloadManager.reconnectDelay(2))
        assertEquals(4_000L, HotReloadManager.reconnectDelay(3))
        assertEquals(8_000L, HotReloadManager.reconnectDelay(4))
        assertEquals(16_000L, HotReloadManager.reconnectDelay(5))
        assertEquals(30_000L, HotReloadManager.reconnectDelay(6))
    }

    @Test
    fun testReconnectDelayStaysCappedForManyAttempts() {
        assertEquals(30_000L, HotReloadManager.reconnectDelay(50))
        assertEquals(30_000L, HotReloadManager.reconnectDelay(10_000))
    }

    @Test
    fun testReconnectDelayNeverNegativeForAttemptBelowOne() {
        // attempt 0 (or lower) must not underflow the exponent; it clamps to the
        // base delay just like attempt 1.
        assertEquals(1_000L, HotReloadManager.reconnectDelay(0))
    }

    // -------------------------------------------------------------------------
    // scheduleReconnect() retries indefinitely — no more giving up after a
    // fixed attempt ceiling (regression test for the old MAX_RECONNECT_ATTEMPTS
    // behavior, which silently killed hot reload if the dev server took longer
    // to come up than ~20s, e.g. a slow-booting emulator).
    // -------------------------------------------------------------------------

    @Test
    fun testReconnectKeepsSchedulingPastTenAttempts() {
        // Regression test for the removed MAX_RECONNECT_ATTEMPTS ceiling: the old
        // code logged "Giving up after 10 attempts..." and returned without ever
        // scheduling another retry. It must now always reach the "Reconnecting
        // in..." log line (immediately followed by mainHandler.postDelayed) no
        // matter how many attempts have already happened.
        //
        // Robolectric's default PAUSED looper mode does not support
        // ShadowLooper.getScheduler() (it throws UnsupportedOperationException),
        // so this asserts the Log.d side effect that only happens on the
        // "schedule another retry" path, rather than inspecting the scheduler.
        //
        // Sets `serverUrl`/`disconnected` directly via reflection instead of
        // calling connect(), which would kick off a real, asynchronous OkHttp
        // WebSocket attempt to ws://localhost:3000 — a connection failure on
        // that background thread could call scheduleReconnect() concurrently
        // with this test's own direct invocation and race reconnectAttempts.
        val scheduleReconnect = HotReloadManager::class.java.getDeclaredMethod("scheduleReconnect")
        scheduleReconnect.isAccessible = true
        val attemptsField = HotReloadManager::class.java.getDeclaredField("reconnectAttempts")
        attemptsField.isAccessible = true
        val serverUrlField = HotReloadManager::class.java.getDeclaredField("serverUrl")
        serverUrlField.isAccessible = true
        val disconnectedField = HotReloadManager::class.java.getDeclaredField("disconnected")
        disconnectedField.isAccessible = true

        serverUrlField.set(manager, "ws://localhost:3000")
        disconnectedField.setBoolean(manager, false)
        attemptsField.setInt(manager, 15)
        ShadowLog.clear()

        scheduleReconnect.invoke(manager)

        assertEquals(
            "reconnectAttempts must keep incrementing rather than being capped",
            16,
            attemptsField.getInt(manager),
        )
        val logs = ShadowLog.getLogsForTag("VueNative-HotReload")
        assertTrue(
            "scheduleReconnect() must still schedule a retry past the old 10-attempt ceiling",
            logs.any { it.msg.contains("Reconnecting in") },
        )
        assertTrue(
            "The removed give-up message must never be logged again",
            logs.none { it.msg.contains("Giving up") },
        )

        manager.disconnect()
    }

    @Test
    fun testConnectedMessageResetsAttemptsAfterManyFailures() {
        val socket = mockk<WebSocket>(relaxed = true)
        val field = HotReloadManager::class.java.getDeclaredField("reconnectAttempts")
        field.isAccessible = true
        field.setInt(manager, 42)

        invokeHandleMessage(socket, "{\"type\":\"connected\"}")

        assertEquals(0, field.getInt(manager))
        // The next reconnect (if the socket later drops) starts back at the
        // base delay instead of continuing from the old backoff level.
        assertEquals(1_000L, HotReloadManager.reconnectDelay(field.getInt(manager) + 1))
    }
}
