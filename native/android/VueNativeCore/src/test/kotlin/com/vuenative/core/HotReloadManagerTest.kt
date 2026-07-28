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
}
