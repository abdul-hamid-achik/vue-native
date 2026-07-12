package com.vuenative.core

import android.content.Context
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import java.io.IOException
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WebSocketModuleTest {

    private lateinit var bridge: NativeBridge
    private lateinit var factory: FakeWebSocketFactory
    private lateinit var module: WebSocketModule
    private val events = mutableListOf<Pair<String, JSONObject>>()

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        bridge = NativeBridge(context).apply {
            onDispatchGlobalEvent = { eventName, payloadJson ->
                events += eventName to JSONObject(payloadJson)
            }
        }
        factory = FakeWebSocketFactory()
        module = WebSocketModule(factory)
    }

    @Test
    fun replacingConnectionSuppressesCallbacksFromOldSocket() {
        connect("socket")
        val first = factory.sockets.single()

        // Queue callbacks while the first socket is current, then replace it
        // before the main-thread lifecycle handler accepts them.
        first.fireOpen()
        first.fireMessage("stale")
        first.fireFailure(IOException("stale failure"))
        first.fireClosed(1006, "stale close")
        connect("socket")
        val second = factory.sockets.last()
        flushMainQueue()

        assertEquals(1, first.cancelCount)
        assertTrue(events.isEmpty())

        second.fireOpen()
        second.fireMessage("current")
        flushMainQueue()

        assertEquals(listOf("websocket:open", "websocket:message"), events.map { it.first })
        assertEquals("current", events.last().second.getString("data"))

        var sendError: String? = "not called"
        module.invoke("send", listOf("socket", "hello"), bridge) { _, error ->
            sendError = error
        }
        assertNull(sendError)
        assertEquals(listOf("hello"), second.sentMessages)
    }

    @Test
    fun explicitCloseEmitsExactlyOneTerminalEvent() {
        connect("socket")
        val socket = factory.sockets.single()

        var closeError: String? = "not called"
        module.invoke("close", listOf("socket", 1000, "done"), bridge) { _, error ->
            closeError = error
        }

        assertNull(closeError)
        assertEquals(1, socket.closeCount)
        assertEquals(listOf("websocket:close"), events.map { it.first })
        assertEquals(1000, events.single().second.getInt("code"))
        assertEquals("done", events.single().second.getString("reason"))

        socket.fireClosed(1000, "done")
        socket.fireFailure(IOException("late failure"))
        flushMainQueue()
        assertEquals(listOf("websocket:close"), events.map { it.first })
    }

    @Test
    fun failureEmitsOneErrorAndOneAbnormalClose() {
        connect("socket")
        val socket = factory.sockets.single()

        socket.fireFailure(IOException("connection failed"))
        socket.fireFailure(IOException("duplicate failure"))
        socket.fireClosed(1006, "duplicate close")
        flushMainQueue()

        assertEquals(listOf("websocket:error", "websocket:close"), events.map { it.first })
        assertEquals("connection failed", events[0].second.getString("message"))
        assertEquals(1006, events[1].second.getInt("code"))
        assertEquals("connection failed", events[1].second.getString("reason"))
    }

    @Test
    fun destroyIsIdempotentAndSuppressesLateEvents() {
        connect("socket")
        val socket = factory.sockets.single()

        module.destroy()
        module.destroy()

        assertEquals(1, socket.cancelCount)
        socket.fireOpen()
        socket.fireMessage("late")
        socket.fireFailure(IOException("late failure"))
        socket.fireClosed(1001, "late close")
        flushMainQueue()
        assertTrue(events.isEmpty())

        var connectError: String? = null
        module.invoke("connect", listOf("wss://example.test", "replacement"), bridge) { _, error ->
            connectError = error
        }
        assertEquals("WebSocketModule: module has been destroyed", connectError)
        assertEquals(1, factory.sockets.size)
    }

    private fun flushMainQueue() {
        Shadows.shadowOf(Looper.getMainLooper()).idle()
    }

    private fun connect(connectionId: String) {
        var result: Any? = null
        var error: String? = "not called"
        module.invoke("connect", listOf("wss://example.test", connectionId), bridge) { value, callbackError ->
            result = value
            error = callbackError
        }
        assertEquals(true, result)
        assertNull(error)
    }

    private class FakeWebSocketFactory : WebSocket.Factory {
        val sockets = mutableListOf<FakeWebSocket>()

        override fun newWebSocket(request: Request, listener: WebSocketListener): WebSocket =
            FakeWebSocket(request, listener).also(sockets::add)
    }

    private class FakeWebSocket(
        private val originalRequest: Request,
        private val listener: WebSocketListener,
    ) : WebSocket {
        val sentMessages = mutableListOf<String>()
        var closeCount = 0
        var cancelCount = 0

        override fun request(): Request = originalRequest

        override fun queueSize(): Long = 0

        override fun send(text: String): Boolean {
            sentMessages += text
            return true
        }

        override fun send(bytes: ByteString): Boolean = true

        override fun close(code: Int, reason: String?): Boolean {
            closeCount++
            return true
        }

        override fun cancel() {
            cancelCount++
        }

        fun fireOpen() {
            listener.onOpen(
                this,
                Response.Builder()
                    .request(originalRequest)
                    .protocol(Protocol.HTTP_1_1)
                    .code(101)
                    .message("Switching Protocols")
                    .build(),
            )
        }

        fun fireMessage(text: String) {
            listener.onMessage(this, text)
        }

        fun fireClosed(code: Int, reason: String) {
            listener.onClosed(this, code, reason)
        }

        fun fireFailure(error: Throwable) {
            listener.onFailure(this, error, null)
        }
    }
}
