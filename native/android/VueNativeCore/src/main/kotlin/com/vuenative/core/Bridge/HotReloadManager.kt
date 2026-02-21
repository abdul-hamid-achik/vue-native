package com.vuenative.core

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Hot reload manager — connects to the Vite dev WebSocket server.
 * On receiving a "full-reload" message, reloads the bundle.
 *
 * Uses OkHttp WebSocket for connectivity.
 */
class HotReloadManager(
    private val runtime: JSRuntime,
    private val onReload: (bundleCode: String) -> Unit
) {
    companion object {
        private const val TAG = "VueNative-HotReload"
        private const val RECONNECT_DELAY_MS = 3000L
    }

    private val scope = CoroutineScope(Dispatchers.IO + Job())
    private var wsSession: okhttp3.WebSocket? = null
    private val httpClient = okhttp3.OkHttpClient()
    private var devServerUrl: String? = null
    private var bundleUrl: String? = null
    private var isConnected = false

    fun connect(wsUrl: String, bundleUrl: String) {
        this.devServerUrl = wsUrl
        this.bundleUrl = bundleUrl
        scope.launch { connectInternal(wsUrl, bundleUrl) }
    }

    private suspend fun connectInternal(wsUrl: String, bundleUrl: String) {
        try {
            val request = okhttp3.Request.Builder().url(wsUrl).build()
            wsSession = httpClient.newWebSocket(request, object : okhttp3.WebSocketListener() {
                override fun onOpen(webSocket: okhttp3.WebSocket, response: okhttp3.Response) {
                    isConnected = true
                    Log.d(TAG, "Connected to dev server: $wsUrl")
                }
                override fun onMessage(webSocket: okhttp3.WebSocket, text: String) {
                    if (text.contains("full-reload") || text.contains("\"type\":\"update\"")) {
                        Log.d(TAG, "Hot reload triggered")
                        fetchAndReload(bundleUrl)
                    }
                }
                override fun onClosed(webSocket: okhttp3.WebSocket, code: Int, reason: String) {
                    isConnected = false
                    Log.d(TAG, "Dev server disconnected: $reason")
                    scope.launch {
                        delay(RECONNECT_DELAY_MS)
                        connectInternal(wsUrl, bundleUrl)
                    }
                }
                override fun onFailure(webSocket: okhttp3.WebSocket, t: Throwable, response: okhttp3.Response?) {
                    isConnected = false
                    Log.w(TAG, "Dev server connection failed: ${t.message}")
                    scope.launch {
                        delay(RECONNECT_DELAY_MS)
                        connectInternal(wsUrl, bundleUrl)
                    }
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect: ${e.message}")
            delay(RECONNECT_DELAY_MS)
            connectInternal(wsUrl, bundleUrl)
        }
    }

    private fun fetchAndReload(bundleUrl: String) {
        scope.launch {
            try {
                val request = okhttp3.Request.Builder().url(bundleUrl).build()
                val response = httpClient.newCall(request).execute()
                if (response.isSuccessful) {
                    val code = response.body?.string() ?: return@launch
                    onReload(code)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to fetch bundle for hot reload: ${e.message}")
            }
        }
    }

    fun disconnect() {
        wsSession?.close(1000, "Shutting down")
        wsSession = null
    }
}
