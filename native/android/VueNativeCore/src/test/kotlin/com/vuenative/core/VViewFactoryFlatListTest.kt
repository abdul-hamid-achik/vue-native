package com.vuenative.core

import android.content.Context
import android.view.View
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Covers VFlatList variable-height support: an item wrapper (a plain VView) is
 * tagged with `__flatListIndex` and given an `itemLayout` listener. After the
 * view is laid out, the factory must report the measured height (in dp) back to
 * JS via the `itemLayout` event, and only when the height actually changes.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VViewFactoryFlatListTest {

    private lateinit var context: Context
    private lateinit var factory: VViewFactory

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        factory = VViewFactory()
    }

    /** Lay the view out at an exact pixel size, triggering layout-change listeners. */
    private fun layoutAt(view: View, widthPx: Int, heightPx: Int) {
        view.measure(
            View.MeasureSpec.makeMeasureSpec(widthPx, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(heightPx, View.MeasureSpec.EXACTLY)
        )
        view.layout(0, 0, widthPx, heightPx)
    }

    @Suppress("UNCHECKED_CAST")
    private fun payloadMap(payload: Any?): Map<String, Any?> = payload as Map<String, Any?>

    @Test
    fun itemLayoutEmitsIndexAndHeightAfterLayout() {
        val view = factory.createView(context)
        factory.updateProp(view, "__flatListIndex", 3)

        val payloads = mutableListOf<Any?>()
        factory.addEventListener(view, "itemLayout") { payloads.add(it) }

        layoutAt(view, widthPx = 200, heightPx = 100)

        assertEquals("exactly one itemLayout event expected", 1, payloads.size)
        val payload = payloadMap(payloads[0])
        assertEquals(3, payload["index"])

        val density = context.resources.displayMetrics.density
        val expectedDp = 100.0 / density
        assertEquals(expectedDp, (payload["height"] as Number).toDouble(), 0.001)
    }

    @Test
    fun itemLayoutWorksWhenListenerRegisteredBeforeProp() {
        val view = factory.createView(context)

        val payloads = mutableListOf<Any?>()
        // Listener arrives first, index prop second — either order must work.
        factory.addEventListener(view, "itemLayout") { payloads.add(it) }
        factory.updateProp(view, "__flatListIndex", 7)

        layoutAt(view, widthPx = 50, heightPx = 80)

        assertEquals(1, payloads.size)
        assertEquals(7, payloadMap(payloads[0])["index"])
    }

    @Test
    fun itemLayoutDoesNotRefireWhenHeightUnchanged() {
        val view = factory.createView(context)
        factory.updateProp(view, "__flatListIndex", 0)

        val payloads = mutableListOf<Any?>()
        factory.addEventListener(view, "itemLayout") { payloads.add(it) }

        layoutAt(view, widthPx = 200, heightPx = 100)
        // Same height again — must not emit a duplicate (avoids feedback loops).
        layoutAt(view, widthPx = 220, heightPx = 100)

        assertEquals("unchanged height must not re-emit", 1, payloads.size)
    }

    @Test
    fun itemLayoutRefiresWhenHeightChanges() {
        val view = factory.createView(context)
        factory.updateProp(view, "__flatListIndex", 1)

        val payloads = mutableListOf<Any?>()
        factory.addEventListener(view, "itemLayout") { payloads.add(it) }

        layoutAt(view, widthPx = 200, heightPx = 100)
        layoutAt(view, widthPx = 200, heightPx = 150)

        assertEquals(2, payloads.size)
        val density = context.resources.displayMetrics.density
        assertEquals(100.0 / density, (payloadMap(payloads[0])["height"] as Number).toDouble(), 0.001)
        assertEquals(150.0 / density, (payloadMap(payloads[1])["height"] as Number).toDouble(), 0.001)
    }

    @Test
    fun itemLayoutDoesNotFireWithoutIndexProp() {
        val view = factory.createView(context)
        // No __flatListIndex prop — this is not a FlatList item wrapper.

        val payloads = mutableListOf<Any?>()
        factory.addEventListener(view, "itemLayout") { payloads.add(it) }

        layoutAt(view, widthPx = 200, heightPx = 100)

        assertTrue("no index => no itemLayout event", payloads.isEmpty())
    }

    @Test
    fun itemLayoutStopsAfterDestroyView() {
        val view = factory.createView(context)
        factory.updateProp(view, "__flatListIndex", 5)

        val payloads = mutableListOf<Any?>()
        factory.addEventListener(view, "itemLayout") { payloads.add(it) }

        layoutAt(view, widthPx = 200, heightPx = 100)
        assertEquals(1, payloads.size)

        factory.destroyView(view)
        // After destroy the listener is detached; further layout must not emit.
        layoutAt(view, widthPx = 200, heightPx = 200)

        assertEquals("destroyView must detach the itemLayout observer", 1, payloads.size)
    }
}
