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

internal enum class VideoPlaybackAction {
    NONE,
    PLAY,
    PAUSE,
}

/**
 * Keeps MediaPlayer state transitions deterministic without touching the player
 * before it has reached the prepared state.
 */
internal data class VideoPlaybackState(
    var autoplay: Boolean = false,
    var paused: Boolean = false,
    var prepared: Boolean = false,
    var volume: Float = 1f,
    var muted: Boolean = false,
) {
    fun updateAutoplay(value: Boolean): VideoPlaybackAction {
        autoplay = value
        return if (prepared && autoplay && !paused) {
            VideoPlaybackAction.PLAY
        } else {
            VideoPlaybackAction.NONE
        }
    }

    fun updatePaused(value: Boolean): VideoPlaybackAction {
        paused = value
        if (!prepared) return VideoPlaybackAction.NONE

        return if (paused) VideoPlaybackAction.PAUSE else VideoPlaybackAction.PLAY
    }

    fun didPrepare(): VideoPlaybackAction {
        prepared = true
        return if (autoplay && !paused) {
            VideoPlaybackAction.PLAY
        } else {
            VideoPlaybackAction.NONE
        }
    }

    fun resetForSource() {
        prepared = false
    }

    fun updateVolume(value: Float) {
        volume = value.coerceIn(0f, 1f)
    }

    fun updateMuted(value: Boolean) {
        muted = value
    }

    fun effectiveVolume(): Float = if (muted) 0f else volume
}

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
    private val playbackStates = mutableMapOf<View, VideoPlaybackState>()
    private val loopFlags = mutableMapOf<View, Boolean>()

    override fun createView(context: Context): View {
        val frame = FrameLayout(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        playbackStates[frame] = VideoPlaybackState()
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
            "autoplay" -> {
                val action = playbackState(frame).updateAutoplay(value as? Boolean ?: false)
                executePlaybackAction(frame, action)
            }
            "loop" -> {
                loopFlags[frame] = value as? Boolean ?: false
                players[frame]?.isLooping = value as? Boolean ?: false
            }
            "muted" -> {
                playbackState(frame).updateMuted(value as? Boolean ?: false)
                applyAudioState(frame)
            }
            "paused" -> {
                val action = playbackState(frame).updatePaused(value as? Boolean ?: false)
                executePlaybackAction(frame, action)
            }
            "volume" -> {
                val vol = (value as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: 1f
                playbackState(frame).updateVolume(vol)
                applyAudioState(frame)
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
                if (players[frame] !== mp) return

                try {
                    mp.setDisplay(holder)
                    mp.setDataSource(uri)
                    mp.isLooping = loopFlags[frame] ?: false
                    applyAudioState(frame, mp)

                    mp.setOnPreparedListener { player ->
                        if (players[frame] !== player) return@setOnPreparedListener

                        val action = playbackState(frame).didPrepare()
                        val duration = player.duration.toDouble() / 1000.0
                        fireEvent(frame, "ready", mapOf("duration" to duration))
                        executePlaybackAction(frame, action, player)
                    }

                    mp.setOnCompletionListener { player ->
                        if (players[frame] !== player) return@setOnCompletionListener

                        stopProgressReporting(frame)
                        fireEvent(frame, "end", null)
                    }

                    mp.setOnErrorListener { player, what, extra ->
                        if (players[frame] !== player) return@setOnErrorListener true

                        stopProgressReporting(frame)
                        playbackState(frame).resetForSource()
                        fireEvent(frame, "error", mapOf("message" to "MediaPlayer error: what=$what extra=$extra"))
                        true
                    }

                    mp.prepareAsync()
                } catch (e: Exception) {
                    if (players[frame] === mp) {
                        val message = e.message ?: "Setup error"
                        cleanupPlayer(frame)
                        fireEvent(frame, "error", mapOf("message" to message))
                    }
                }
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}
            override fun surfaceDestroyed(holder: SurfaceHolder) {
                if (players[frame] === mp) {
                    try {
                        mp.setDisplay(null)
                    } catch (_: IllegalStateException) {
                        // The player may have been released during a source change.
                    }
                }
            }
        })
    }

    private fun cleanupPlayer(frame: FrameLayout) {
        stopProgressReporting(frame)
        playbackStates[frame]?.resetForSource()
        val player = players.remove(frame)
        player?.setOnPreparedListener(null)
        player?.setOnCompletionListener(null)
        player?.setOnErrorListener(null)
        player?.release()
        frame.removeAllViews()
    }

    private fun playbackState(frame: FrameLayout): VideoPlaybackState =
        playbackStates.getOrPut(frame) { VideoPlaybackState() }

    private fun executePlaybackAction(
        frame: FrameLayout,
        action: VideoPlaybackAction,
        player: MediaPlayer? = players[frame],
    ) {
        if (action == VideoPlaybackAction.NONE || player == null || players[frame] !== player) return

        try {
            when (action) {
                VideoPlaybackAction.NONE -> Unit
                VideoPlaybackAction.PLAY -> {
                    player.start()
                    startProgressReporting(frame, player)
                }
                VideoPlaybackAction.PAUSE -> {
                    if (player.isPlaying) player.pause()
                    stopProgressReporting(frame)
                }
            }
        } catch (_: IllegalStateException) {
            // A source replacement may release the old player between callbacks.
        }
    }

    private fun applyAudioState(frame: FrameLayout, player: MediaPlayer? = players[frame]) {
        if (player == null || players[frame] !== player) return

        val volume = playbackState(frame).effectiveVolume()
        try {
            player.setVolume(volume, volume)
        } catch (_: IllegalStateException) {
            // A source replacement may release the old player between callbacks.
        }
    }

    private fun startProgressReporting(
        frame: FrameLayout,
        expectedPlayer: MediaPlayer? = players[frame],
    ) {
        stopProgressReporting(frame)
        if (expectedPlayer == null || players[frame] !== expectedPlayer) return

        val runnable = object : Runnable {
            override fun run() {
                if (players[frame] !== expectedPlayer) return

                try {
                    if (expectedPlayer.isPlaying) {
                        fireEvent(frame, "progress", mapOf(
                            "currentTime" to expectedPlayer.currentPosition.toDouble() / 1000.0,
                            "duration" to expectedPlayer.duration.toDouble() / 1000.0
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

    override fun destroyView(view: View) {
        val frame = view as? FrameLayout ?: return
        cleanupPlayer(frame)
        handlers.remove(frame)
        playbackStates.remove(frame)
        loopFlags.remove(frame)
    }
}
