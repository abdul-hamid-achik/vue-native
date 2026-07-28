package com.vuenative.core

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

/**
 * Accessibility module backing the `useAccessibility()` composable.
 *
 * - `announce(message)` speaks a message through TalkBack without moving focus.
 * - `setFocus(nodeId)` moves accessibility focus to the view registered for `nodeId`.
 *
 * All view work runs on the main thread. Failures are best-effort: they are
 * reported through the callback rather than crashing the host.
 */
class AccessibilityModule : NativeModule {
    override val moduleName = "Accessibility"
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        when (method) {
            "announce", "announceForAccessibility" -> handleAnnounce(args, bridge, callback)
            "setFocus" -> handleSetFocus(args, bridge, callback)
            else -> callback(null, "Unknown method: $method")
        }
    }

    private fun handleAnnounce(args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val message = args.getOrNull(0)?.toString()
        if (message.isNullOrEmpty()) {
            callback(null, "announce: message is required")
            return
        }
        // Prefer the composed root view; fall back to the host container so an
        // announcement still works before the root view has been attached.
        val target = bridge.rootView ?: bridge.hostContainer ?: run {
            callback(null, "announce: no root view available")
            return
        }
        mainHandler.post {
            runCatching { target.announceForAccessibility(message) }
                .onSuccess { callback(null, null) }
                .onFailure { error -> callback(null, "announce: ${error.message ?: "failed"}") }
        }
    }

    private fun handleSetFocus(args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val nodeId = StyleEngine.toInt(args.getOrNull(0), -1)
        val view = bridge.nodeViews[nodeId] ?: run {
            callback(null, "setFocus: view $nodeId not found")
            return
        }
        mainHandler.post {
            runCatching {
                view.requestFocus()
                view.sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED)
            }
                .onSuccess { callback(null, null) }
                .onFailure { error -> callback(null, "setFocus: ${error.message ?: "failed"}") }
        }
    }

    override fun initialize(context: Context, bridge: NativeBridge) {
        // No setup required; views are resolved from the bridge per invocation.
    }
}
