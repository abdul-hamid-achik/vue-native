package com.vuenative.core

import android.app.Activity
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AccessibilityModuleTest {
    private lateinit var activity: Activity
    private lateinit var bridge: NativeBridge
    private lateinit var module: AccessibilityModule

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        bridge = NativeBridge(activity).also { it.hostContainer = FrameLayout(activity) }
        module = AccessibilityModule().also { it.initialize(activity, bridge) }
    }

    @Test
    fun announceCompletesWithoutError() {
        bridge.rootView = View(activity)
        var called = false
        var callbackError: String? = "not_called"

        module.invoke("announce", listOf("3 items added"), bridge) { _, error ->
            called = true
            callbackError = error
        }
        shadowOf(Looper.getMainLooper()).idle()

        assertTrue("announce callback should fire", called)
        assertNull(callbackError)
    }

    @Test
    fun announceFallsBackToHostContainerWhenRootViewMissing() {
        // rootView is null; hostContainer from setUp should be used.
        var callbackError: String? = "not_called"

        module.invoke("announce", listOf("Hello"), bridge) { _, error -> callbackError = error }
        shadowOf(Looper.getMainLooper()).idle()

        assertNull(callbackError)
    }

    @Test
    fun announceWithoutMessageReturnsError() {
        bridge.rootView = View(activity)
        var callbackError: String? = null

        module.invoke("announce", emptyList(), bridge) { _, error -> callbackError = error }
        shadowOf(Looper.getMainLooper()).idle()

        assertNotNull(callbackError)
    }

    @Test
    fun setFocusWithValidNodeCompletesWithoutError() {
        val view = View(activity).apply { isFocusable = true }
        bridge.nodeViews[7] = view
        var called = false
        var callbackError: String? = "not_called"

        module.invoke("setFocus", listOf(7), bridge) { _, error ->
            called = true
            callbackError = error
        }
        shadowOf(Looper.getMainLooper()).idle()

        assertTrue("setFocus callback should fire", called)
        assertNull(callbackError)
    }

    @Test
    fun setFocusWithInvalidNodeReturnsError() {
        var callbackError: String? = null

        module.invoke("setFocus", listOf(999), bridge) { _, error -> callbackError = error }
        shadowOf(Looper.getMainLooper()).idle()

        assertNotNull(callbackError)
        assertTrue(callbackError!!.contains("not found"))
    }

    @Test
    fun unknownMethodReturnsError() {
        var callbackError: String? = null

        module.invoke("bogus", emptyList(), bridge) { _, error -> callbackError = error }

        assertNotNull(callbackError)
    }
}
