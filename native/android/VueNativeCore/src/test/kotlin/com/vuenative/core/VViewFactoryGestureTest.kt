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
 * Covers the extended native-driven gestures: when a view declares
 * `nativeDrivenGestures = ["pinch"]` the pinch handler applies the scale factor
 * to `scaleX/scaleY`, and `["rotate"]` applies the rotation delta to `rotation`,
 * both on the UI thread. The matching JS event still fires in every case; native
 * drive only changes who paints the intermediate frames.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VViewFactoryGestureTest {

    private lateinit var context: Context
    private lateinit var factory: VViewFactory

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        factory = VViewFactory()
    }

    // -- Multi-pointer event helpers -----------------------------------------

    private fun multiEvent(action: Int, downTime: Long, eventTime: Long, vararg pts: Pair<Float, Float>): MotionEvent {
        val n = pts.size
        val props = Array(n) { i ->
            MotionEvent.PointerProperties().apply {
                id = i
                toolType = MotionEvent.TOOL_TYPE_FINGER
            }
        }
        val coords = Array(n) { i ->
            MotionEvent.PointerCoords().apply {
                x = pts[i].first
                y = pts[i].second
                pressure = 1f
                size = 1f
            }
        }
        return MotionEvent.obtain(
            downTime, eventTime, action, n, props, coords,
            0, 0, 1f, 1f, 0, 0, 0, 0
        )
    }

    /**
     * Dispatch a two-finger gesture: first finger down, second finger down, then
     * a MOVE event per supplied (p0, p1) frame. Advances event time so the
     * gesture detectors see well-formed, time-ordered events.
     */
    private fun dispatchTwoFinger(view: View, frames: List<Pair<Pair<Float, Float>, Pair<Float, Float>>>) {
        val downTime = SystemClock.uptimeMillis()
        var t = downTime
        view.dispatchTouchEvent(multiEvent(MotionEvent.ACTION_DOWN, downTime, t, frames[0].first))
        t += 16
        view.dispatchTouchEvent(
            multiEvent(
                MotionEvent.ACTION_POINTER_DOWN or (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT),
                downTime, t, frames[0].first, frames[0].second
            )
        )
        for (i in 1 until frames.size) {
            t += 16
            view.dispatchTouchEvent(multiEvent(MotionEvent.ACTION_MOVE, downTime, t, frames[i].first, frames[i].second))
        }
    }

    // -- Pinch ---------------------------------------------------------------

    /** Frames that spread two fingers apart (span 100 -> 300px). */
    private fun spreadFrames(): List<Pair<Pair<Float, Float>, Pair<Float, Float>>> {
        val anchor = 100f to 100f
        return listOf(
            anchor to (200f to 100f),
            anchor to (230f to 100f),
            anchor to (270f to 100f),
            anchor to (320f to 100f),
            anchor to (400f to 100f),
        )
    }

    @Test
    fun nativeDrivenPinchAppliesScaleToView() {
        val view = factory.createView(context)
        factory.updateProp(view, "nativeDrivenGestures", JSONArray().put("pinch"))

        val payloads = mutableListOf<Any?>()
        factory.addEventListener(view, "pinch") { payloads.add(it) }

        dispatchTwoFinger(view, spreadFrames())

        assertTrue(
            "scaleX should grow with a spreading pinch, was ${view.scaleX}",
            view.scaleX > 1.0f,
        )
        assertTrue(
            "scaleY should grow with a spreading pinch, was ${view.scaleY}",
            view.scaleY > 1.0f,
        )
        assertEquals("scaleX and scaleY must stay uniform", view.scaleX, view.scaleY, 0.0001f)
        assertTrue("pinch event should still fire to JS", payloads.isNotEmpty())
    }

    @Test
    fun pinchWithoutNativeDriveLeavesScaleUntouched() {
        val view = factory.createView(context)
        // No nativeDrivenGestures prop set.

        val payloads = mutableListOf<Any?>()
        factory.addEventListener(view, "pinch") { payloads.add(it) }

        dispatchTwoFinger(view, spreadFrames())

        assertEquals("scaleX must stay 1 without native drive", 1f, view.scaleX, 0.0001f)
        assertEquals("scaleY must stay 1 without native drive", 1f, view.scaleY, 0.0001f)
        assertTrue("pinch event should fire to JS even without native drive", payloads.isNotEmpty())
    }

    // -- Rotate --------------------------------------------------------------

    /**
     * Frames that rotate the finger pair by +90deg about the anchor: the second
     * finger moves from (100, 0) relative to the anchor to (0, 100).
     */
    private fun rotateFrames(): List<Pair<Pair<Float, Float>, Pair<Float, Float>>> {
        val anchor = 0f to 0f
        return listOf(
            anchor to (100f to 0f),
            anchor to (0f to 100f),
        )
    }

    @Test
    fun nativeDrivenRotateAppliesRotationToView() {
        val view = factory.createView(context)
        factory.updateProp(view, "nativeDrivenGestures", JSONArray().put("rotate"))

        val payloads = mutableListOf<Any?>()
        factory.addEventListener(view, "rotate") { payloads.add(it) }

        dispatchTwoFinger(view, rotateFrames())

        // The finger pair rotated +90deg (PI/2 rad) about the anchor.
        assertEquals("rotation should track the gesture, was ${view.rotation}", 90f, view.rotation, 1f)
        assertTrue("rotate event should still fire to JS", payloads.isNotEmpty())
    }

    @Test
    fun rotateWithoutNativeDriveLeavesRotationUntouched() {
        val view = factory.createView(context)
        // No nativeDrivenGestures prop set.

        val payloads = mutableListOf<Any?>()
        factory.addEventListener(view, "rotate") { payloads.add(it) }

        dispatchTwoFinger(view, rotateFrames())

        assertEquals("rotation must stay 0 without native drive", 0f, view.rotation, 0.0001f)
        assertTrue("rotate event should fire to JS even without native drive", payloads.isNotEmpty())
    }

    @Test
    fun unrelatedGestureNameDoesNotDriveRotate() {
        val view = factory.createView(context)
        // Native drive requested for a different gesture, not rotate.
        factory.updateProp(view, "nativeDrivenGestures", JSONArray().put("pinch"))

        factory.addEventListener(view, "rotate") { }

        dispatchTwoFinger(view, rotateFrames())

        assertEquals("rotate must not be native-driven", 0f, view.rotation, 0.0001f)
    }
}
