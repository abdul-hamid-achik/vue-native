package com.vuenative.core

import android.content.Context
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import org.json.JSONObject

/**
 * VVideoFactory — factory for the VVideo component.
 * Uses SurfaceView + MediaPlayer for inline video playback.
 */
class VVideoFactory : NativeComponentFactory {

    private val handlers = mutableMapOf<View, MutableMap<String, (Any?) -> Unit>>()
    private val players = mutableMapOf<View, MediaPlayer?>()
    private val progressHandlers = mutableMapOf<View, Runnable?>()
    private val uiHandler = Handler(Looper.getMainLooper())

    // Per-view state
    private val autoplayFlags = mutableMapOf<View, Boolean>()
    private val loopFlags = mutableMapOf<View, Boolean>()
    private val mutedFlags = mutableMapOf<View, Boolean>()

    override fun createView(context: Context): View {
        val frame = FrameLayout(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        return frame
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val frame = view as? FrameLayout ?: return

        when (key) {
            "source" -> {
                val uri = when (value) {
                    is Map<*, *> -> value["uri"]?.toString()
                    is JSONObject -> value.optString("uri")
                    else -> null
                }
                if (uri.isNullOrEmpty()) {
                    cleanupPlayer(frame)
                    return
                }
                setupPlayer(frame, uri)
            }
            "autoplay" -> autoplayFlags[frame] = value as? Boolean ?: false
            "loop" -> {
                loopFlags[frame] = value as? Boolean ?: false
                players[frame]?.isLooping = value as? Boolean ?: false
            }
            "muted" -> {
                mutedFlags[frame] = value as? Boolean ?: false
                val vol = if (value as? Boolean == true) 0f else 1f
                players[frame]?.setVolume(vol, vol)
            }
            "paused" -> {
                val paused = value as? Boolean ?: false
                val mp = players[frame]
                if (paused) {
                    mp?.pause()
                } else {
                    mp?.start()
                    startProgressReporting(frame)
                }
            }
            "volume" -> {
                val vol = (value as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: 1f
                players[frame]?.setVolume(vol, vol)
            }
            "resizeMode" -> {
                // SurfaceView doesn't directly support resize modes like AVPlayerLayer
                // We could implement custom scaling via matrix transforms in the future
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val map = handlers.getOrPut(view) { mutableMapOf() }
        map[event] = handler
    }

    override fun removeEventListener(view: View, event: String) {
        handlers[view]?.remove(event)
    }

    // MARK: - Player setup

    private fun setupPlayer(frame: FrameLayout, uri: String) {
        cleanupPlayer(frame)

        val surfaceView = SurfaceView(frame.context)
        frame.addView(surfaceView, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ))

        val mp = MediaPlayer()
        players[frame] = mp

        surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                try {
                    mp.setDisplay(holder)
                    mp.setDataSource(uri)
                    mp.isLooping = loopFlags[frame] ?: false

                    val muted = mutedFlags[frame] ?: false
                    if (muted) mp.setVolume(0f, 0f)

                    mp.setOnPreparedListener { player ->
                        val duration = player.duration.toDouble() / 1000.0
                        fireEvent(frame, "ready", mapOf("duration" to duration))
                        if (autoplayFlags[frame] == true) {
                            player.start()
                            startProgressReporting(frame)
                        }
                    }

                    mp.setOnCompletionListener {
                        stopProgressReporting(frame)
                        fireEvent(frame, "end", null)
                    }

                    mp.setOnErrorListener { _, what, extra ->
                        stopProgressReporting(frame)
                        fireEvent(frame, "error", mapOf("message" to "MediaPlayer error: what=$what extra=$extra"))
                        true
                    }

                    mp.prepareAsync()
                } catch (e: Exception) {
                    fireEvent(frame, "error", mapOf("message" to (e.message ?: "Setup error")))
                }
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}
            override fun surfaceDestroyed(holder: SurfaceHolder) {
                mp.setDisplay(null)
            }
        })
    }

    private fun cleanupPlayer(frame: FrameLayout) {
        stopProgressReporting(frame)
        players[frame]?.release()
        players.remove(frame)
        frame.removeAllViews()
    }

    private fun startProgressReporting(frame: FrameLayout) {
        stopProgressReporting(frame)
        val runnable = object : Runnable {
            override fun run() {
                val mp = players[frame] ?: return
                try {
                    if (mp.isPlaying) {
                        fireEvent(frame, "progress", mapOf(
                            "currentTime" to mp.currentPosition.toDouble() / 1000.0,
                            "duration" to mp.duration.toDouble() / 1000.0
                        ))
                        uiHandler.postDelayed(this, 250)
                    }
                } catch (_: IllegalStateException) {
                    // Player may have been released
                }
            }
        }
        progressHandlers[frame] = runnable
        uiHandler.postDelayed(runnable, 250)
    }

    private fun stopProgressReporting(frame: FrameLayout) {
        progressHandlers[frame]?.let { uiHandler.removeCallbacks(it) }
        progressHandlers.remove(frame)
    }

    private fun fireEvent(view: View, event: String, payload: Any?) {
        handlers[view]?.get(event)?.invoke(payload)
    }
}
