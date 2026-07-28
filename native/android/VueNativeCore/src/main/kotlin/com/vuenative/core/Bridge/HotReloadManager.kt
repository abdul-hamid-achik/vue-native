package com.vuenative.core

import android.os.Handler
import android.os.Looper
import android.util.Log
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject

/**
 * Hot reload manager — connects to the Vue Native dev server over WebSocket.
 *
 * Wire protocol (see `packages/cli/src/commands/dev.ts`), all messages are JSON:
 * - Server sends `{ "type": "connected" }` once the socket is accepted.
 * - Server sends `{ "type": "ping" }`; the client must reply `{ "type": "pong" }`.
 * - Server sends `{ "type": "bundle", "bundle": "<code>" }` with the entire bundle
 *   inline. The client reloads using that string directly — there is no separate
 *   HTTP bundle fetch.
 *
 * Mirrors `native/shared/.../HotReloadManager.swift`.
 */
class HotReloadManager(
    private val onReload: (bundleCode: String) -> Unit,
) {
    companion object {
        private const val TAG = "VueNative-HotReload"
        private const val RECONNECT_DELAY_MS = 2000L
        private const val MAX_RECONNECT_ATTEMPTS = 10

        /**
         * Append the hot-reload auth token as a `token` query parameter when it is
         * non-empty. The token is a hex string emitted by the Vite plugin, so it
         * needs no percent-encoding. A base URL that already carries a query string
         * gets the token joined with `&` instead of `?`. An empty token returns the
         * base URL unchanged — the dev server only enforces the token when it is
         * exposed to the network via `--lan`, so the tokenless URL stays valid.
         */
        fun hotReloadUrl(base: String, token: String): String {
            if (token.isEmpty()) return base
            val separator = if (base.contains('?')) "&" else "?"
            return "$base${separator}token=$token"
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val httpClient = OkHttpClient()
    private var webSocket: WebSocket? = null
    private var serverUrl: String? = null
    private var reconnectAttempts = 0

    @Volatile
    private var disconnected = false

    /** Connect to the dev server WebSocket. Safe to call once per manager. */
    fun connect(wsUrl: String) {
        serverUrl = wsUrl
        reconnectAttempts = 0
        disconnected = false
        openConnection()
    }

    /** Disconnect and stop reconnecting. */
    fun disconnect() {
        disconnected = true
        serverUrl = null
        mainHandler.removeCallbacksAndMessages(null)
        webSocket?.close(1000, "Shutting down")
        webSocket = null
    }

    private fun openConnection() {
        val url = serverUrl ?: return
        if (disconnected) return
        Log.d(TAG, "Connecting to dev server: $url")
        val request = Request.Builder().url(url).build()
        webSocket = httpClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket opened")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleMessage(webSocket, text)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "Dev server disconnected: $reason")
                scheduleReconnect()
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.w(TAG, "Dev server connection failed: ${t.message}")
                scheduleReconnect()
            }
        })
    }

    private fun handleMessage(webSocket: WebSocket, text: String) {
        val json = try {
            JSONObject(text)
        } catch (e: Exception) {
            Log.w(TAG, "Ignoring non-JSON dev server message")
            return
        }
        when (json.optString("type")) {
            "connected" -> {
                reconnectAttempts = 0
                Log.d(TAG, "Connected — hot reload active")
            }
            "ping" -> {
                // Keep-alive: the server expects a pong reply.
                webSocket.send("{\"type\":\"pong\"}")
            }
            "bundle" -> {
                val bundle = json.optString("bundle", "")
                if (bundle.isEmpty()) {
                    Log.w(TAG, "Received empty bundle; ignoring")
                    return
                }
                Log.d(TAG, "Received bundle (${bundle.length} bytes) — reloading")
                mainHandler.post { onReload(bundle) }
            }
            else -> {
                // Unknown message type — ignore for forward compatibility.
            }
        }
    }

    private fun scheduleReconnect() {
        if (disconnected || serverUrl == null) return
        reconnectAttempts += 1
        if (reconnectAttempts > MAX_RECONNECT_ATTEMPTS) {
            Log.w(
                TAG,
                "Giving up after $MAX_RECONNECT_ATTEMPTS attempts — start `bun run dev` and relaunch the app",
            )
            return
        }
        Log.d(TAG, "Reconnecting in ${RECONNECT_DELAY_MS}ms (attempt $reconnectAttempts/$MAX_RECONNECT_ATTEMPTS)")
        mainHandler.postDelayed({ openConnection() }, RECONNECT_DELAY_MS)
    }
}
