package com.vuenative.example.counter

/**
 * Release variant: hot reload is disabled.
 *
 * A shipping build must never open a plaintext WebSocket and evaluate whatever
 * JavaScript arrives on it — that endpoint has full native-module privileges
 * (file system, camera, secure storage). Keep this returning `null`.
 */
internal object DevServer {
    val url: String? = null
}
