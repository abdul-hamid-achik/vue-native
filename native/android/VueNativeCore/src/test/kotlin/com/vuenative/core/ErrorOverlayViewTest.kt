package com.vuenative.core

import android.content.Context
import android.graphics.Typeface
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

    private fun card(activity: AppCompatActivity): LinearLayout {
        val decorView = activity.window.decorView as android.view.ViewGroup
        val overlay = decorView.findViewWithTag<FrameLayout>("vue_native_error_overlay")
        assertNotNull("Overlay should be added to decorView", overlay)
        return overlay!!.getChildAt(0) as LinearLayout
    }

    private fun findWithTag(parent: android.view.ViewGroup, tag: String): android.view.View? {
        for (i in 0 until parent.childCount) {
            val child = parent.getChildAt(i)
            if (child.tag == tag) return child
            if (child is android.view.ViewGroup) {
                val nested = findWithTag(child, tag)
                if (nested != null) return nested
            }
        }
        return null
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
    // parse() — structured JSON payload from the runtime errorHandler
    // -------------------------------------------------------------------------

    @Test
    fun testParseStructuredJson() {
        val json = """{"message":"boom","stack":"at foo (app.js:1:2)","componentName":"MyComp","info":"render"}"""
        val parsed = ErrorOverlayView.parse(json)
        assertEquals("boom", parsed.message)
        assertEquals("at foo (app.js:1:2)", parsed.stack)
        assertEquals("MyComp", parsed.componentName)
    }

    @Test
    fun testParseJsonWithoutComponentName() {
        val parsed = ErrorOverlayView.parse("""{"message":"boom","stack":"trace"}""")
        assertEquals("boom", parsed.message)
        assertEquals("trace", parsed.stack)
        assertNull("componentName should be null when absent", parsed.componentName)
    }

    @Test
    fun testParseBlankStackAndComponentBecomeNull() {
        val parsed = ErrorOverlayView.parse("""{"message":"boom","stack":"","componentName":""}""")
        assertEquals("boom", parsed.message)
        assertNull(parsed.stack)
        assertNull(parsed.componentName)
    }

    @Test
    fun testParsePlainTextFallback() {
        val parsed = ErrorOverlayView.parse("Failed to load bundle: missing asset")
        assertEquals("Failed to load bundle: missing asset", parsed.message)
        assertNull(parsed.stack)
        assertNull(parsed.componentName)
    }

    @Test
    fun testParseInvalidJsonTreatedAsPlainText() {
        val parsed = ErrorOverlayView.parse("{not valid json")
        assertEquals("{not valid json", parsed.message)
        assertNull(parsed.stack)
        assertNull(parsed.componentName)
    }

    // -------------------------------------------------------------------------
    // show() with non-activity context does not crash
    // -------------------------------------------------------------------------

    @Test
    fun testShowWithNonActivityContext() {
        // Application context is not an Activity, so show() should return early.
        ErrorOverlayView.show(context, "Test error")
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
    // Overlay renders message (bold), scrollable stack, and a Reload button
    // -------------------------------------------------------------------------

    @Test
    fun testOverlayRendersStructuredPayload() {
        val activity = createActivity()
        val json = """{"message":"Cannot read property 'value' of null","stack":"at render (app.js:10:5)","componentName":"Counter"}"""

        ErrorOverlayView.show(activity, json)

        val card = card(activity)

        // Message — bold and matching the payload.
        val message = findWithTag(card, "vue_native_error_message") as TextView
        assertEquals("Cannot read property 'value' of null", message.text.toString())
        assertEquals("Message should be bold", Typeface.DEFAULT_BOLD, message.typeface)

        // Component name rendered because the payload carries one.
        val component = findWithTag(card, "vue_native_error_component") as TextView
        assertEquals("Component: Counter", component.text.toString())

        // Stack — monospace inside a ScrollView.
        val scroll = findWithTag(card, "vue_native_error_scroll")
        assertNotNull("Stack should be inside a ScrollView", scroll)
        assertTrue(scroll is ScrollView)
        val stack = findWithTag(card, "vue_native_error_stack") as TextView
        assertEquals("at render (app.js:10:5)", stack.text.toString())
        assertEquals(android.graphics.Typeface.MONOSPACE, stack.typeface)

        // Reload button exists.
        val reload = findWithTag(card, "vue_native_error_reload")
        assertNotNull("Reload button should exist", reload)
        assertTrue(reload is Button)
        assertEquals("Reload", (reload as Button).text.toString())
    }

    @Test
    fun testOverlayOmitsComponentWhenAbsent() {
        val activity = createActivity()

        ErrorOverlayView.show(activity, "plain failure")

        val card = card(activity)
        assertNull(
            "Component label should be omitted for plain-text errors",
            findWithTag(card, "vue_native_error_component"),
        )
        val message = findWithTag(card, "vue_native_error_message") as TextView
        assertEquals("plain failure", message.text.toString())
    }

    // -------------------------------------------------------------------------
    // Reload button invokes the configurable callback
    // -------------------------------------------------------------------------

    @Test
    fun testReloadInvokesCallback() {
        val activity = createActivity()
        var reloaded = false

        ErrorOverlayView.show(activity, "Some error") { reloaded = true }

        val card = card(activity)
        val reload = findWithTag(card, "vue_native_error_reload") as Button
        reload.performClick()

        assertTrue("Reload callback should fire", reloaded)
        val decorView = activity.window.decorView as android.view.ViewGroup
        assertNull(
            "Overlay should be removed on reload",
            decorView.findViewWithTag<FrameLayout>("vue_native_error_overlay"),
        )
    }

    // -------------------------------------------------------------------------
    // Dismiss button removes overlay
    // -------------------------------------------------------------------------

    @Test
    fun testDismissRemovesOverlay() {
        val activity = createActivity()

        ErrorOverlayView.show(activity, "Some error")

        val decorView = activity.window.decorView as android.view.ViewGroup
        assertNotNull(decorView.findViewWithTag<FrameLayout>("vue_native_error_overlay"))

        val card = card(activity)
        val dismiss = findWithTag(card, "vue_native_error_dismiss") as Button
        dismiss.performClick()

        assertNull(
            "Overlay should be removed after dismiss",
            decorView.findViewWithTag<FrameLayout>("vue_native_error_overlay"),
        )
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

        var overlayCount = 0
        for (i in 0 until decorView.childCount) {
            if (decorView.getChildAt(i).tag == "vue_native_error_overlay") {
                overlayCount++
            }
        }
        assertEquals("Should only have one overlay", 1, overlayCount)

        val card = card(activity)
        val message = findWithTag(card, "vue_native_error_message") as TextView
        assertEquals("Second error", message.text.toString())
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
