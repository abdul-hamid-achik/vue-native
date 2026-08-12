package com.vuenative.core

import android.content.pm.ApplicationInfo
import android.os.Looper
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class HotReloadStatusViewTest {

    /**
     * [debuggable] mirrors [ErrorOverlayViewTest]'s pattern: [HotReloadStatusView.update]
     * gates its badge on the *host application's* debuggability, not this library's own
     * build type.
     */
    private fun createActivity(debuggable: Boolean = true): AppCompatActivity {
        val controller = Robolectric.buildActivity(AppCompatActivity::class.java)
        val activity = controller.get()
        activity.setTheme(androidx.appcompat.R.style.Theme_AppCompat)
        activity.applicationInfo.flags = if (debuggable) {
            activity.applicationInfo.flags or ApplicationInfo.FLAG_DEBUGGABLE
        } else {
            activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE.inv()
        }
        controller.create().start().resume()
        return activity
    }

    private fun pill(activity: AppCompatActivity): TextView? {
        val decorView = activity.window.decorView as android.view.ViewGroup
        return decorView.findViewWithTag("vue_native_hot_reload_status")
    }

    // -------------------------------------------------------------------------
    // present() — pure state -> presentation mapping
    // -------------------------------------------------------------------------

    @Test
    fun presentConnectingAtOrBelowThreeAttemptsIsConnectingText() {
        listOf(0, 1, 2, 3).forEach { attempt ->
            val presentation = HotReloadStatusView.present(HotReloadStatus.Connecting(attempt))
            assertEquals("attempt=$attempt", "Connecting…", presentation.text)
            assertNull(presentation.autoHideDelayMs)
        }
    }

    @Test
    fun presentConnectingAboveThreeAttemptsIsDisconnectedText() {
        listOf(4, 5, 100).forEach { attempt ->
            val presentation = HotReloadStatusView.present(HotReloadStatus.Connecting(attempt))
            assertEquals("attempt=$attempt", "Disconnected — check `vue-native dev`", presentation.text)
            assertNull(presentation.autoHideDelayMs)
        }
    }

    @Test
    fun presentConnectedAutoHidesAfterTwoSeconds() {
        val presentation = HotReloadStatusView.present(HotReloadStatus.Connected)
        assertEquals("Connected", presentation.text)
        assertEquals(2_000L, presentation.autoHideDelayMs)
    }

    @Test
    fun presentUsesDistinctColorsPerState() {
        val connecting = HotReloadStatusView.present(HotReloadStatus.Connecting(1))
        val disconnected = HotReloadStatusView.present(HotReloadStatus.Connecting(4))
        val connected = HotReloadStatusView.present(HotReloadStatus.Connected)

        val colors = setOf(connecting.backgroundColor, disconnected.backgroundColor, connected.backgroundColor)
        assertEquals("Each state must render a distinct color", 3, colors.size)
    }

    // -------------------------------------------------------------------------
    // update() — gated on host debuggability, like ErrorOverlayView
    // -------------------------------------------------------------------------

    @Test
    fun updateDoesNothingWhenHostIsNotDebuggable() {
        val activity = createActivity(debuggable = false)

        HotReloadStatusView.update(activity, HotReloadStatus.Connecting(0))

        assertNull("Badge must not render for a non-debuggable host", pill(activity))
    }

    @Test
    fun updateRendersBadgeWhenHostIsDebuggable() {
        val activity = createActivity(debuggable = true)

        HotReloadStatusView.update(activity, HotReloadStatus.Connecting(0))

        val badge = pill(activity)
        assertNotNull("Badge should render for a debuggable host", badge)
        assertEquals("Connecting…", badge!!.text.toString())
        assertTrue("Badge must not intercept touches", !badge.isClickable && !badge.isFocusable)
    }

    @Test
    fun updateSwitchesToDisconnectedTextPastThreeAttempts() {
        val activity = createActivity()

        HotReloadStatusView.update(activity, HotReloadStatus.Connecting(4))

        assertEquals("Disconnected — check `vue-native dev`", pill(activity)!!.text.toString())
    }

    @Test
    fun updateReusesTheSameBadgeInstanceAcrossCalls() {
        val activity = createActivity()

        HotReloadStatusView.update(activity, HotReloadStatus.Connecting(0))
        val first = pill(activity)
        HotReloadStatusView.update(activity, HotReloadStatus.Connecting(1))
        val second = pill(activity)

        assertTrue("update() should mutate the existing badge rather than adding a new one", first === second)
    }

    // -------------------------------------------------------------------------
    // Connected state auto-hides after 2s and reappears on the next status
    // -------------------------------------------------------------------------

    @Test
    fun connectedBadgeAutoHidesAfterTwoSeconds() {
        val activity = createActivity()

        HotReloadStatusView.update(activity, HotReloadStatus.Connected)
        assertEquals(android.view.View.VISIBLE, pill(activity)!!.visibility)

        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofMillis(2_000))

        assertEquals(android.view.View.GONE, pill(activity)!!.visibility)
    }

    @Test
    fun badgeReappearsWhenConnectionIsLostAfterAutoHide() {
        val activity = createActivity()

        HotReloadStatusView.update(activity, HotReloadStatus.Connected)
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofMillis(2_000))
        assertEquals(android.view.View.GONE, pill(activity)!!.visibility)

        HotReloadStatusView.update(activity, HotReloadStatus.Connecting(1))

        assertEquals(android.view.View.VISIBLE, pill(activity)!!.visibility)
        assertEquals("Connecting…", pill(activity)!!.text.toString())
    }

    @Test
    fun laterUpdateCancelsAPendingAutoHide() {
        val activity = createActivity()

        HotReloadStatusView.update(activity, HotReloadStatus.Connected)
        // Connection drops again before the 2s auto-hide fires.
        HotReloadStatusView.update(activity, HotReloadStatus.Connecting(1))

        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofMillis(2_000))

        assertEquals(
            "The stale auto-hide from the earlier Connected state must not hide the new Connecting badge",
            android.view.View.VISIBLE,
            pill(activity)!!.visibility,
        )
        assertEquals("Connecting…", pill(activity)!!.text.toString())
    }

    // -------------------------------------------------------------------------
    // hide() removes the badge entirely
    // -------------------------------------------------------------------------

    @Test
    fun hideRemovesTheBadge() {
        val activity = createActivity()

        HotReloadStatusView.update(activity, HotReloadStatus.Connecting(0))
        assertNotNull(pill(activity))

        HotReloadStatusView.hide(activity)

        assertNull(pill(activity))
    }

    @Test
    fun hideWithNoBadgePresentDoesNotThrow() {
        val activity = createActivity()
        HotReloadStatusView.hide(activity)
        assertTrue(true)
    }
}
