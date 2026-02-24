package com.vuenative.core

import android.content.Context
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.io.File
import java.util.UUID

/**
 * AudioModule — backs the useAudio() composable.
 *
 * Playback: MediaPlayer (play, pause, resume, stop, seek, setVolume)
 * Recording: MediaRecorder (startRecording, stopRecording, pauseRecording, resumeRecording)
 * Events: audio:progress, audio:complete, audio:error
 */
class AudioModule : NativeModule {
    override val moduleName = "Audio"

    private var player: MediaPlayer? = null
    private var recorder: MediaRecorder? = null
    private var recordingPath: String? = null
    private var bridge: NativeBridge? = null
    private var context: Context? = null
    private var isPlaying = false

    private val handler = Handler(Looper.getMainLooper())
    private var progressRunnable: Runnable? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context
        this.bridge = bridge
    }

    override fun invoke(
        method: String,
        args: List<Any?>,
        bridge: NativeBridge,
        callback: (Any?, String?) -> Unit
    ) {
        when (method) {
            "play" -> {
                val uri = args.getOrNull(0)?.toString() ?: ""
                @Suppress("UNCHECKED_CAST")
                val options = (args.getOrNull(1) as? Map<String, Any?>) ?: emptyMap()
                play(uri, options, callback)
            }
            "pause" -> pause(callback)
            "resume" -> resume(callback)
            "stop" -> stop(callback)
            "seek" -> {
                val position = when (val v = args.getOrNull(0)) {
                    is Number -> v.toDouble()
                    else -> 0.0
                }
                seek(position, callback)
            }
            "setVolume" -> {
                val volume = when (val v = args.getOrNull(0)) {
                    is Number -> v.toFloat()
                    else -> 1.0f
                }
                setVolume(volume, callback)
            }
            "startRecording" -> {
                @Suppress("UNCHECKED_CAST")
                val options = (args.getOrNull(0) as? Map<String, Any?>) ?: emptyMap()
                startRecording(options, callback)
            }
            "stopRecording" -> stopRecording(callback)
            "pauseRecording" -> pauseRecording(callback)
            "resumeRecording" -> resumeRecording(callback)
            "getStatus" -> getStatus(callback)
            else -> callback(null, "AudioModule: Unknown method '$method'")
        }
    }

    // MARK: - Playback

    private fun play(uri: String, options: Map<String, Any?>, callback: (Any?, String?) -> Unit) {
        handler.post {
            try {
                stopProgressReporting()
                player?.release()
                player = null

                val mp = MediaPlayer()
                mp.setDataSource(uri)

                val volume = (options["volume"] as? Number)?.toFloat() ?: 1.0f
                val loop = options["loop"] as? Boolean ?: false

                mp.setVolume(volume, volume)
                mp.isLooping = loop

                mp.setOnPreparedListener {
                    it.start()
                    isPlaying = true
                    startProgressReporting()
                    callback(mapOf(
                        "duration" to it.duration.toDouble() / 1000.0,
                        "currentTime" to 0.0
                    ), null)
                }

                mp.setOnCompletionListener {
                    isPlaying = false
                    stopProgressReporting()
                    bridge?.dispatchGlobalEvent("audio:complete", emptyMap())
                }

                mp.setOnErrorListener { _, what, extra ->
                    isPlaying = false
                    stopProgressReporting()
                    val msg = "MediaPlayer error: what=$what extra=$extra"
                    bridge?.dispatchGlobalEvent("audio:error", mapOf("message" to msg))
                    true
                }

                player = mp
                mp.prepareAsync()
            } catch (e: Exception) {
                callback(null, "Failed to play audio: ${e.message}")
            }
        }
    }

    private fun pause(callback: (Any?, String?) -> Unit) {
        handler.post {
            player?.pause()
            isPlaying = false
            stopProgressReporting()
            callback(null, null)
        }
    }

    private fun resume(callback: (Any?, String?) -> Unit) {
        handler.post {
            player?.start()
            isPlaying = true
            startProgressReporting()
            callback(null, null)
        }
    }

    private fun stop(callback: (Any?, String?) -> Unit) {
        handler.post {
            stopProgressReporting()
            player?.release()
            player = null
            isPlaying = false
            callback(null, null)
        }
    }

    private fun seek(position: Double, callback: (Any?, String?) -> Unit) {
        handler.post {
            val ms = (position * 1000).toInt()
            player?.seekTo(ms)
            callback(null, null)
        }
    }

    private fun setVolume(volume: Float, callback: (Any?, String?) -> Unit) {
        handler.post {
            val v = volume.coerceIn(0f, 1f)
            player?.setVolume(v, v)
            callback(null, null)
        }
    }

    // MARK: - Progress Reporting

    private fun startProgressReporting() {
        stopProgressReporting()
        val runnable = object : Runnable {
            override fun run() {
                val mp = player ?: return
                if (isPlaying) {
                    bridge?.dispatchGlobalEvent("audio:progress", mapOf(
                        "currentTime" to mp.currentPosition.toDouble() / 1000.0,
                        "duration" to mp.duration.toDouble() / 1000.0
                    ))
                    handler.postDelayed(this, 250)
                }
            }
        }
        progressRunnable = runnable
        handler.postDelayed(runnable, 250)
    }

    private fun stopProgressReporting() {
        progressRunnable?.let { handler.removeCallbacks(it) }
        progressRunnable = null
    }

    // MARK: - Recording

    private fun startRecording(options: Map<String, Any?>, callback: (Any?, String?) -> Unit) {
        handler.post {
            try {
                val ctx = context ?: run {
                    callback(null, "No context available")
                    return@post
                }

                val quality = options["quality"]?.toString() ?: "medium"
                val format = options["format"]?.toString() ?: "m4a"

                val ext = if (format == "wav") "wav" else "m4a"
                val file = File(ctx.cacheDir, "${UUID.randomUUID()}.$ext")
                recordingPath = file.absolutePath

                val mr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    MediaRecorder(ctx)
                } else {
                    @Suppress("DEPRECATION")
                    MediaRecorder()
                }

                mr.setAudioSource(MediaRecorder.AudioSource.MIC)

                if (format == "wav") {
                    // WAV not directly supported by MediaRecorder — use 3GPP as fallback
                    mr.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP)
                    mr.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
                } else {
                    mr.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                    mr.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                    when (quality) {
                        "low" -> {
                            mr.setAudioSamplingRate(22050)
                            mr.setAudioEncodingBitRate(32000)
                        }
                        "high" -> {
                            mr.setAudioSamplingRate(44100)
                            mr.setAudioEncodingBitRate(128000)
                        }
                        else -> {
                            mr.setAudioSamplingRate(44100)
                            mr.setAudioEncodingBitRate(64000)
                        }
                    }
                }

                mr.setOutputFile(file.absolutePath)
                mr.prepare()
                mr.start()
                recorder = mr

                callback(mapOf("uri" to "file://${file.absolutePath}"), null)
            } catch (e: Exception) {
                callback(null, "Failed to start recording: ${e.message}")
            }
        }
    }

    private fun stopRecording(callback: (Any?, String?) -> Unit) {
        handler.post {
            val mr = recorder
            val path = recordingPath
            if (mr == null || path == null) {
                callback(null, "No active recording")
                return@post
            }
            try {
                mr.stop()
                mr.release()
                recorder = null

                // Get duration by briefly opening the file with MediaPlayer
                val mp = MediaPlayer()
                mp.setDataSource(path)
                mp.prepare()
                val duration = mp.duration.toDouble() / 1000.0
                mp.release()

                callback(mapOf(
                    "uri" to "file://$path",
                    "duration" to duration
                ), null)
            } catch (e: Exception) {
                callback(null, "Failed to stop recording: ${e.message}")
            }
        }
    }

    private fun pauseRecording(callback: (Any?, String?) -> Unit) {
        handler.post {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                recorder?.pause()
            }
            callback(null, null)
        }
    }

    private fun resumeRecording(callback: (Any?, String?) -> Unit) {
        handler.post {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                recorder?.resume()
            }
            callback(null, null)
        }
    }

    // MARK: - Status

    private fun getStatus(callback: (Any?, String?) -> Unit) {
        handler.post {
            val status = mutableMapOf<String, Any>(
                "isPlaying" to isPlaying,
                "isRecording" to (recorder != null)
            )
            player?.let {
                status["currentTime"] = it.currentPosition.toDouble() / 1000.0
                status["duration"] = it.duration.toDouble() / 1000.0
            }
            callback(status, null)
        }
    }

    override fun destroy() {
        stopProgressReporting()
        player?.release()
        player = null
        recorder?.release()
        recorder = null
    }
}
