package com.vuenative.core

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.Choreographer

/**
 * Native module for performance profiling.
 * Tracks FPS via Choreographer, memory usage via Runtime, and bridge operation counts.
 * Dispatches `perf:metrics` global events every 1 second while profiling is active.
 */
class PerformanceModule : NativeModule {
    override val moduleName = "Performance"

    private var bridge: NativeBridge? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isProfiling = false

    // FPS tracking
    private var frameCount = 0
    private var lastFrameTimeNanos = 0L
    private var currentFPS = 0.0

    // Bridge operation count
    private var bridgeOpsCount = 0

    // Metrics timer
    private var metricsRunnable: Runnable? = null

    // Choreographer callback
    private var frameCallback: Choreographer.FrameCallback? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.bridge = bridge
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (result: Any?, error: String?) -> Unit
    ) {
        when (method) {
            "startProfiling" -> startProfiling(callback)
            "stopProfiling" -> stopProfiling(callback)
            "getMetrics" -> callback(collectMetrics(), null)
            else -> callback(null, "PerformanceModule: unknown method '$method'")
        }
    }

    // ── Start / Stop ──────────────────────────────────────────────────────

    private fun startProfiling(callback: (Any?, String?) -> Unit) {
        if (isProfiling) {
            callback(true, null)
            return
        }
        isProfiling = true
        frameCount = 0
        lastFrameTimeNanos = 0
        currentFPS = 0.0
        bridgeOpsCount = 0

        mainHandler.post {
            // Choreographer for FPS measurement
            frameCallback = object : Choreographer.FrameCallback {
                override fun doFrame(frameTimeNanos: Long) {
                    if (!isProfiling) return

                    if (lastFrameTimeNanos == 0L) {
                        lastFrameTimeNanos = frameTimeNanos
                        frameCount = 0
                    } else {
                        frameCount++
                        val elapsedNanos = frameTimeNanos - lastFrameTimeNanos
                        val elapsedSeconds = elapsedNanos / 1_000_000_000.0

                        // Calculate FPS every 0.5 seconds
                        if (elapsedSeconds >= 0.5) {
                            currentFPS = frameCount / elapsedSeconds
                            frameCount = 0
                            lastFrameTimeNanos = frameTimeNanos
                        }
                    }

                    Choreographer.getInstance().postFrameCallback(this)
                }
            }
            Choreographer.getInstance().postFrameCallback(frameCallback!!)

            // Periodic metrics dispatch (every 1 second)
            metricsRunnable = object : Runnable {
                override fun run() {
                    if (!isProfiling) return
                    dispatchMetrics()
                    mainHandler.postDelayed(this, 1000)
                }
            }
            mainHandler.postDelayed(metricsRunnable!!, 1000)
        }

        callback(true, null)
    }

    private fun stopProfiling(callback: (Any?, String?) -> Unit) {
        if (!isProfiling) {
            callback(true, null)
            return
        }
        isProfiling = false

        mainHandler.post {
            frameCallback?.let { Choreographer.getInstance().removeFrameCallback(it) }
            frameCallback = null
            metricsRunnable?.let { mainHandler.removeCallbacks(it) }
            metricsRunnable = null
        }

        callback(true, null)
    }

    // ── Metrics collection ────────────────────────────────────────────────

    private fun collectMetrics(): Map<String, Any> {
        val runtime = Runtime.getRuntime()
        val usedMemory = (runtime.totalMemory() - runtime.freeMemory()).toDouble() / (1024 * 1024)

        return mapOf(
            "fps" to Math.round(currentFPS * 10.0) / 10.0,
            "memoryMB" to Math.round(usedMemory * 100.0) / 100.0,
            "bridgeOps" to bridgeOpsCount,
            "timestamp" to System.currentTimeMillis()
        )
    }

    private fun dispatchMetrics() {
        if (!isProfiling) return
        bridgeOpsCount++
        val metrics = collectMetrics()
        bridge?.dispatchGlobalEvent("perf:metrics", metrics)
    }

    override fun destroy() {
        isProfiling = false
        mainHandler.post {
            frameCallback?.let { Choreographer.getInstance().removeFrameCallback(it) }
            frameCallback = null
            metricsRunnable?.let { mainHandler.removeCallbacks(it) }
            metricsRunnable = null
        }
    }
}
