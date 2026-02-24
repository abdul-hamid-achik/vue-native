package com.vuenative.core

import android.content.Context
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * Native module for WebSocket connections using OkHttp.
 *
 * Supports multiple simultaneous connections keyed by connection ID.
 *
 * Methods:
 *   - connect(url, connectionId)
 *   - send(connectionId, data)
 *   - close(connectionId, code?, reason?)
 *
 * Global events:
 *   "websocket:open"    { connectionId }
 *   "websocket:message" { connectionId, data }
 *   "websocket:close"   { connectionId, code, reason }
 *   "websocket:error"   { connectionId, message }
 */
class WebSocketModule : NativeModule {
    override val moduleName = "WebSocket"

    private var bridge: NativeBridge? = null
    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS) // No read timeout for WebSocket
        .build()
    private val connections = ConcurrentHashMap<String, WebSocket>()

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.bridge = bridge
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "connect" -> {
                val url = args.getOrNull(0) as? String
                    ?: run { callback(null, "WebSocketModule: expected url"); return }
                val connectionId = args.getOrNull(1) as? String
                    ?: run { callback(null, "WebSocketModule: expected connectionId"); return }
                connect(url, connectionId, bridge, callback)
            }
            "send" -> {
                val connectionId = args.getOrNull(0) as? String
                    ?: run { callback(null, "WebSocketModule: expected connectionId"); return }
                val data = args.getOrNull(1) as? String
                    ?: run { callback(null, "WebSocketModule: expected data"); return }
                send(connectionId, data, callback)
            }
            "close" -> {
                val connectionId = args.getOrNull(0) as? String
                    ?: run { callback(null, "WebSocketModule: expected connectionId"); return }
                val code = (args.getOrNull(1) as? Number)?.toInt() ?: 1000
                val reason = args.getOrNull(2) as? String ?: ""
                close(connectionId, code, reason, bridge, callback)
            }
            else -> callback(null, "WebSocketModule: Unknown method '$method'")
        }
    }

    private fun connect(url: String, connectionId: String, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        // Close existing connection if any
        connections.remove(connectionId)?.cancel()

        val request = Request.Builder()
            .url(url)
            .build()

        val ws = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                bridge.dispatchGlobalEvent("websocket:open", mapOf(
                    "connectionId" to connectionId
                ))
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                bridge.dispatchGlobalEvent("websocket:message", mapOf(
                    "connectionId" to connectionId,
                    "data" to text
                ))
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(code, reason)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                connections.remove(connectionId)
                bridge.dispatchGlobalEvent("websocket:close", mapOf(
                    "connectionId" to connectionId,
                    "code" to code,
                    "reason" to reason
                ))
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                connections.remove(connectionId)
                bridge.dispatchGlobalEvent("websocket:error", mapOf(
                    "connectionId" to connectionId,
                    "message" to (t.message ?: "WebSocket error")
                ))
                bridge.dispatchGlobalEvent("websocket:close", mapOf(
                    "connectionId" to connectionId,
                    "code" to 1006,
                    "reason" to (t.message ?: "WebSocket error")
                ))
            }
        })

        connections[connectionId] = ws
        callback(true, null)
    }

    private fun send(connectionId: String, data: String, callback: (Any?, String?) -> Unit) {
        val ws = connections[connectionId]
            ?: run { callback(null, "WebSocketModule: no connection '$connectionId'"); return }
        val sent = ws.send(data)
        if (sent) {
            callback(true, null)
        } else {
            callback(null, "WebSocketModule: failed to send message")
        }
    }

    private fun close(connectionId: String, code: Int, reason: String, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val ws = connections.remove(connectionId)
        if (ws != null) {
            ws.close(code, reason)
            bridge.dispatchGlobalEvent("websocket:close", mapOf(
                "connectionId" to connectionId,
                "code" to code,
                "reason" to reason
            ))
        }
        // Not an error if already closed
        callback(true, null)
    }

    override fun destroy() {
        connections.values.forEach { it.cancel() }
        connections.clear()
    }
}
