package com.vuenative.core

import android.content.Context
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import androidx.test.core.app.ApplicationProvider
import org.json.JSONArray
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Covers the native-driven pan gesture: when a view declares
 * `nativeDrivenGestures = ["pan"]`, the pan handler applies the accumulated
 * translation directly to the view's transform on the UI thread, while still
 * firing the `pan` event to JS. Without the prop, the transform is untouched
 * and only the JS event fires.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VViewFactoryPanTest {

    private lateinit var context: Context
    private lateinit var factory: VViewFactory

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        factory = VViewFactory()
    }

    @Test
    fun nativeDrivenPanAppliesTranslationToView() {
        val view = factory.createView(context)
        factory.updateProp(view, "nativeDrivenGestures", JSONArray().put("pan"))

        val payloads = mutableListOf<Any?>()
        factory.addEventListener(view, "pan") { payloads.add(it) }

        dispatchDrag(view, from = 100f, to = 200f, steps = 5)

        // The view moved along with the finger (dragged right/down by ~100px).
        assertTrue(
            "translationX should track the drag, was ${view.translationX}",
            view.translationX > 50f,
        )
        assertTrue(
            "translationY should track the drag, was ${view.translationY}",
            view.translationY > 50f,
        )
        // The JS event still fires for every scroll callback.
        assertTrue("pan event should still fire to JS", payloads.isNotEmpty())
    }

    @Test
    fun panWithoutNativeDriveLeavesTransformUntouched() {
        val view = factory.createView(context)
        // No nativeDrivenGestures prop set.

        val payloads = mutableListOf<Any?>()
        factory.addEventListener(view, "pan") { payloads.add(it) }

        dispatchDrag(view, from = 100f, to = 200f, steps = 5)

        assertEquals("translationX must stay 0 without native drive", 0f, view.translationX, 0.001f)
        assertEquals("translationY must stay 0 without native drive", 0f, view.translationY, 0.001f)
        // The JS event still fires — native drive only changes who paints frames.
        assertTrue("pan event should fire to JS even without native drive", payloads.isNotEmpty())
    }

    @Test
    fun nativeDrivenPanAcceptsListProp() {
        val view = factory.createView(context)
        // The bridge normally sends a JSONArray, but a Kotlin List must also work.
        factory.updateProp(view, "nativeDrivenGestures", listOf("pan"))

        factory.addEventListener(view, "pan") { }

        dispatchDrag(view, from = 100f, to = 200f, steps = 5)

        assertTrue("translationX should track the drag (List prop)", view.translationX > 50f)
    }

    @Test
    fun nativeDrivenPanPreservesBaselineTransform() {
        val view = factory.createView(context)
        // A pre-existing transform translation (e.g. from a style transform).
        view.translationX = 40f
        view.translationY = 10f
        factory.updateProp(view, "nativeDrivenGestures", JSONArray().put("pan"))

        factory.addEventListener(view, "pan") { }

        dispatchDrag(view, from = 100f, to = 200f, steps = 5)

        // The drag is added on top of the baseline, not measured from zero.
        assertTrue(
            "translationX should be baseline + drag, was ${view.translationX}",
            view.translationX > 40f + 50f,
        )
        assertTrue(
            "translationY should be baseline + drag, was ${view.translationY}",
            view.translationY > 10f + 50f,
        )
    }

    @Test
    fun unrelatedGestureNameDoesNotDrivePan() {
        val view = factory.createView(context)
        // Native drive requested for a different gesture, not pan.
        factory.updateProp(view, "nativeDrivenGestures", JSONArray().put("pinch"))

        factory.addEventListener(view, "pan") { }

        dispatchDrag(view, from = 100f, to = 200f, steps = 5)

        assertEquals("pan must not be native-driven", 0f, view.translationX, 0.001f)
        assertEquals("pan must not be native-driven", 0f, view.translationY, 0.001f)
    }

    /**
     * Dispatch a synthetic single-pointer drag from (from, from) to (to, to)
     * through the view's touch pipeline so the GestureDetector recognizes a
     * scroll. Advances event time so the events are well-formed.
     */
    private fun dispatchDrag(view: View, from: Float, to: Float, steps: Int) {
        val downTime = SystemClock.uptimeMillis()
        var eventTime = downTime
        view.dispatchTouchEvent(obtainEvent(MotionEvent.ACTION_DOWN, from, from, downTime, eventTime))
        for (i in 1..steps) {
            eventTime += 16
            val pos = from + (to - from) * i / steps
            view.dispatchTouchEvent(obtainEvent(MotionEvent.ACTION_MOVE, pos, pos, downTime, eventTime))
        }
        eventTime += 16
        view.dispatchTouchEvent(obtainEvent(MotionEvent.ACTION_UP, to, to, downTime, eventTime))
    }

    private fun obtainEvent(action: Int, x: Float, y: Float, downTime: Long, eventTime: Long): MotionEvent =
        MotionEvent.obtain(downTime, eventTime, action, x, y, 0)
}
