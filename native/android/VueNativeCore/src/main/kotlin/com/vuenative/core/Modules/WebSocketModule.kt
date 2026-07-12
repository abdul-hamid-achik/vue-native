package com.vuenative.core

import android.os.Handler
import android.os.Looper
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener

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
class WebSocketModule internal constructor(
    private val webSocketFactory: WebSocket.Factory,
) : NativeModule {
    constructor() : this(
        OkHttpClient.Builder()
            .readTimeout(0, TimeUnit.MILLISECONDS)
            .build(),
    )

    override val moduleName = "WebSocket"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val connections = ConcurrentHashMap<String, WebSocket>()
    @Volatile private var destroyed = false

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "connect" -> {
                val url = args.getOrNull(0) as? String
                    ?: run {
                        callback(null, "WebSocketModule: expected url")
                        return
                    }
                val connectionId = args.getOrNull(1) as? String
                    ?: run {
                        callback(null, "WebSocketModule: expected connectionId")
                        return
                    }
                connect(url, connectionId, bridge, callback)
            }
            "send" -> {
                val connectionId = args.getOrNull(0) as? String
                    ?: run {
                        callback(null, "WebSocketModule: expected connectionId")
                        return
                    }
                val data = args.getOrNull(1) as? String
                    ?: run {
                        callback(null, "WebSocketModule: expected data")
                        return
                    }
                send(connectionId, data, callback)
            }
            "close" -> {
                val connectionId = args.getOrNull(0) as? String
                    ?: run {
                        callback(null, "WebSocketModule: expected connectionId")
                        return
                    }
                val code = (args.getOrNull(1) as? Number)?.toInt() ?: 1000
                val reason = args.getOrNull(2) as? String ?: ""
                close(connectionId, code, reason, bridge, callback)
            }
            else -> callback(null, "WebSocketModule: Unknown method '$method'")
        }
    }

    private fun connect(url: String, connectionId: String, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        if (destroyed) {
            callback(null, "WebSocketModule: module has been destroyed")
            return
        }

        // Close existing connection if any
        connections.remove(connectionId)?.cancel()

        val request = Request.Builder()
            .url(url)
            .build()

        val ws = webSocketFactory.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                mainHandler.post {
                    if (!isCurrent(connectionId, webSocket)) return@post
                    bridge.dispatchGlobalEvent("websocket:open", mapOf(
                        "connectionId" to connectionId
                    ))
                }
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                mainHandler.post {
                    if (!isCurrent(connectionId, webSocket)) return@post
                    bridge.dispatchGlobalEvent("websocket:message", mapOf(
                        "connectionId" to connectionId,
                        "data" to text
                    ))
                }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                mainHandler.post {
                    if (isCurrent(connectionId, webSocket)) {
                        webSocket.close(code, reason)
                    }
                }
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                mainHandler.post {
                    if (!removeCurrent(connectionId, webSocket)) return@post
                    bridge.dispatchGlobalEvent("websocket:close", mapOf(
                        "connectionId" to connectionId,
                        "code" to code,
                        "reason" to reason
                    ))
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                mainHandler.post {
                    if (!removeCurrent(connectionId, webSocket)) return@post
                    val message = t.message ?: "WebSocket error"
                    bridge.dispatchGlobalEvent("websocket:error", mapOf(
                        "connectionId" to connectionId,
                        "message" to message
                    ))
                    bridge.dispatchGlobalEvent("websocket:close", mapOf(
                        "connectionId" to connectionId,
                        "code" to 1006,
                        "reason" to message
                    ))
                }
            }
        })

        connections[connectionId] = ws
        callback(true, null)
    }

    private fun send(connectionId: String, data: String, callback: (Any?, String?) -> Unit) {
        val ws = connections[connectionId]?.takeUnless { destroyed }
            ?: run {
                callback(null, "WebSocketModule: no connection '$connectionId'")
                return
            }
        val sent = ws.send(data)
        if (sent) {
            callback(true, null)
        } else {
            callback(null, "WebSocketModule: failed to send message")
        }
    }

    private fun close(connectionId: String, code: Int, reason: String, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val ws = connections.remove(connectionId)
        if (ws != null && !destroyed) {
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

    private fun isCurrent(connectionId: String, webSocket: WebSocket): Boolean =
        !destroyed && connections[connectionId] === webSocket

    private fun removeCurrent(connectionId: String, webSocket: WebSocket): Boolean =
        !destroyed && connections.remove(connectionId, webSocket)

    override fun destroy() {
        if (destroyed) return
        destroyed = true
        mainHandler.removeCallbacksAndMessages(null)
        val activeConnections = connections.values.toList()
        connections.clear()
        activeConnections.forEach { it.cancel() }
    }
}
