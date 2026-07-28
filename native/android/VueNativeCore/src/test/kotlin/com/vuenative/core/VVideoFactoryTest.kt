package com.vuenative.core

import android.content.Context
import android.media.MediaPlayer
import android.view.View
import android.widget.FrameLayout
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VVideoFactoryTest {

    private lateinit var context: Context
    private lateinit var factory: VVideoFactory

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        factory = VVideoFactory()
    }

    /**
     * Bypass the asynchronous SurfaceView/MediaPlayer preparation flow by
     * injecting an already-prepared playback state and a mock player, so the
     * play/pause event emission in `executePlaybackAction` can be exercised
     * deterministically through the public `updateProp` API.
     */
    private fun injectPreparedPlayer(frame: FrameLayout, player: MediaPlayer) {
        val playersField = VVideoFactory::class.java.getDeclaredField("players")
        playersField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        (playersField.get(factory) as MutableMap<View, MediaPlayer?>)[frame] = player

        val statesField = VVideoFactory::class.java.getDeclaredField("playbackStates")
        statesField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        (statesField.get(factory) as MutableMap<View, VideoPlaybackState>)[frame] =
            VideoPlaybackState(prepared = true)
    }

    @Test
    fun pauseEventFiresWhenPausingAPlayingVideo() {
        val frame = factory.createView(context) as FrameLayout
        val events = mutableListOf<String>()
        factory.addEventListener(frame, "play") { events.add("play") }
        factory.addEventListener(frame, "pause") { events.add("pause") }

        val player = mockk<MediaPlayer>(relaxed = true)
        every { player.isPlaying } returns true
        injectPreparedPlayer(frame, player)

        factory.updateProp(frame, "paused", true)

        assertTrue("pause event should fire when a playing video is paused", events.contains("pause"))
        assertFalse("play event should not fire on pause", events.contains("play"))
        verify { player.pause() }
    }

    @Test
    fun playEventFiresWhenResumingAPausedVideo() {
        val frame = factory.createView(context) as FrameLayout
        val events = mutableListOf<String>()
        factory.addEventListener(frame, "play") { events.add("play") }
        factory.addEventListener(frame, "pause") { events.add("pause") }

        val player = mockk<MediaPlayer>(relaxed = true)
        every { player.isPlaying } returns false
        injectPreparedPlayer(frame, player)

        // Pause first (no-op event-wise because nothing is playing), then resume.
        factory.updateProp(frame, "paused", true)
        factory.updateProp(frame, "paused", false)

        assertTrue("play event should fire when playback resumes", events.contains("play"))
        assertFalse("pause event should not fire when nothing was playing", events.contains("pause"))
        verify { player.start() }
    }
}
