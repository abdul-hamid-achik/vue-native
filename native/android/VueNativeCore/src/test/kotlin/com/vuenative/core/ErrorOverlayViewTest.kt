package com.vuenative.core

import android.content.Context
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ErrorOverlayViewTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
    }

    private fun createActivity(): AppCompatActivity {
        val controller = Robolectric.buildActivity(AppCompatActivity::class.java)
        val activity = controller.get()
        activity.setTheme(androidx.appcompat.R.style.Theme_AppCompat)
        controller.create().start().resume()
        return activity
    }

    // -------------------------------------------------------------------------
    // ErrorOverlayView is a singleton object
    // -------------------------------------------------------------------------

    @Test
    fun testIsSingletonObject() {
        val ref1 = ErrorOverlayView
        val ref2 = ErrorOverlayView
        assertTrue("ErrorOverlayView should be a singleton object", ref1 === ref2)
    }

    // -------------------------------------------------------------------------
    // show() with non-activity context does not crash
    // -------------------------------------------------------------------------

    @Test
    fun testShowWithNonActivityContext() {
        // Application context is not an AppCompatActivity, so show() should return early
        ErrorOverlayView.show(context, "Test error")
        // Should not crash
        assertTrue(true)
    }

    // -------------------------------------------------------------------------
    // show() with Activity creates overlay
    // -------------------------------------------------------------------------

    @Test
    fun testShowWithActivity() {
        val activity = createActivity()

        ErrorOverlayView.show(activity, "Runtime error: undefined is not a function")

        val decorView = activity.window.decorView as? android.view.ViewGroup
        assertNotNull("decorView should not be null", decorView)

        val overlay = decorView?.findViewWithTag<FrameLayout>("vue_native_error_overlay")
        assertNotNull("Overlay should be added to decorView", overlay)
    }

    // -------------------------------------------------------------------------
    // Overlay contains title, error text, and dismiss button
    // -------------------------------------------------------------------------

    @Test
    fun testOverlayContents() {
        val activity = createActivity()

        val errorMessage = "TypeError: Cannot read property 'value' of null"
        ErrorOverlayView.show(activity, errorMessage)

        val decorView = activity.window.decorView as android.view.ViewGroup
        val overlay = decorView.findViewWithTag<FrameLayout>("vue_native_error_overlay")!!

        // The overlay contains a card (LinearLayout)
        val card = overlay.getChildAt(0) as LinearLayout

        // Card should have 3 children: title, scroll (with error text), dismiss button
        assertEquals("Card should have 3 children", 3, card.childCount)

        // Title
        val title = card.getChildAt(0) as TextView
        assertEquals("Vue Native JS Error", title.text.toString())

        // Scroll -> error text
        val scroll = card.getChildAt(1) as ScrollView
        val errorText = scroll.getChildAt(0) as TextView
        assertEquals(errorMessage, errorText.text.toString())

        // Dismiss button
        val dismiss = card.getChildAt(2) as Button
        assertEquals("Dismiss", dismiss.text.toString())
    }

    // -------------------------------------------------------------------------
    // Dismiss button removes overlay
    // -------------------------------------------------------------------------

    @Test
    fun testDismissRemovesOverlay() {
        val activity = createActivity()

        ErrorOverlayView.show(activity, "Some error")

        val decorView = activity.window.decorView as android.view.ViewGroup
        var overlay = decorView.findViewWithTag<FrameLayout>("vue_native_error_overlay")
        assertNotNull("Overlay should exist", overlay)

        // Find and click the dismiss button
        val card = overlay!!.getChildAt(0) as LinearLayout
        val dismiss = card.getChildAt(2) as Button
        dismiss.performClick()

        overlay = decorView.findViewWithTag<FrameLayout>("vue_native_error_overlay")
        assertNull("Overlay should be removed after dismiss", overlay)
    }

    // -------------------------------------------------------------------------
    // Showing twice replaces old overlay
    // -------------------------------------------------------------------------

    @Test
    fun testShowTwiceReplacesOverlay() {
        val activity = createActivity()

        ErrorOverlayView.show(activity, "First error")
        ErrorOverlayView.show(activity, "Second error")

        val decorView = activity.window.decorView as android.view.ViewGroup

        // Count overlays with the tag
        var overlayCount = 0
        for (i in 0 until decorView.childCount) {
            if (decorView.getChildAt(i).tag == "vue_native_error_overlay") {
                overlayCount++
            }
        }
        assertEquals("Should only have one overlay", 1, overlayCount)

        // Verify it shows the second error
        val overlay = decorView.findViewWithTag<FrameLayout>("vue_native_error_overlay")!!
        val card = overlay.getChildAt(0) as LinearLayout
        val scroll = card.getChildAt(1) as ScrollView
        val errorText = scroll.getChildAt(0) as TextView
        assertEquals("Second error", errorText.text.toString())
    }

    // -------------------------------------------------------------------------
    // Overlay tag is correct
    // -------------------------------------------------------------------------

    @Test
    fun testOverlayTag() {
        val activity = createActivity()

        ErrorOverlayView.show(activity, "Error")

        val decorView = activity.window.decorView as android.view.ViewGroup
        val overlay = decorView.findViewWithTag<FrameLayout>("vue_native_error_overlay")
        assertNotNull("Overlay should be findable by tag", overlay)
        assertEquals("vue_native_error_overlay", overlay!!.tag)
    }
}
