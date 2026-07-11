package com.vuenative.core

import org.junit.Assert.assertEquals
import org.junit.Test

class VVideoPlaybackStateTest {
    @Test
    fun defaultPausedFalseDoesNotActAsAutoplay() {
        val state = VideoPlaybackState()

        assertEquals(VideoPlaybackAction.NONE, state.updatePaused(false))
        assertEquals(VideoPlaybackAction.NONE, state.didPrepare())
    }

    @Test
    fun autoplayAndPausedAreHonoredAtPreparation() {
        val autoplaying = VideoPlaybackState()
        assertEquals(VideoPlaybackAction.NONE, autoplaying.updateAutoplay(true))
        assertEquals(VideoPlaybackAction.PLAY, autoplaying.didPrepare())

        val blocked = VideoPlaybackState()
        assertEquals(VideoPlaybackAction.NONE, blocked.updateAutoplay(true))
        assertEquals(VideoPlaybackAction.NONE, blocked.updatePaused(true))
        assertEquals(VideoPlaybackAction.NONE, blocked.didPrepare())
    }

    @Test
    fun pausedChangesDoNothingBeforePreparationAndControlPlaybackAfterward() {
        val state = VideoPlaybackState()

        assertEquals(VideoPlaybackAction.NONE, state.updatePaused(true))
        assertEquals(VideoPlaybackAction.NONE, state.updatePaused(false))
        assertEquals(VideoPlaybackAction.NONE, state.didPrepare())
        assertEquals(VideoPlaybackAction.PLAY, state.updatePaused(false))
        assertEquals(VideoPlaybackAction.PAUSE, state.updatePaused(true))

        state.resetForSource()
        assertEquals(VideoPlaybackAction.NONE, state.updatePaused(false))
    }

    @Test
    fun volumeAndMutePersistAcrossSourcesWithoutMakingMutedPlaybackAudible() {
        val state = VideoPlaybackState()

        state.updateVolume(0.35f)
        assertEquals(0.35f, state.effectiveVolume(), 0.001f)

        state.updateMuted(true)
        state.updateVolume(0.8f)
        state.resetForSource()
        assertEquals(0f, state.effectiveVolume(), 0.001f)

        state.updateMuted(false)
        assertEquals(0.8f, state.effectiveVolume(), 0.001f)
    }
}
