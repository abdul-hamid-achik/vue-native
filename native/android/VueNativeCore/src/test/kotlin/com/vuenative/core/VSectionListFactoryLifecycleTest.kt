package com.vuenative.core

import android.content.Context
import android.view.View
import androidx.recyclerview.widget.RecyclerView
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VSectionListFactoryLifecycleTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
    }

    @Test
    fun destroyViewReleasesRecyclerViewStateAndAdapter() {
        val factory = VSectionListFactory()
        val recyclerView = factory.createView(context) as RecyclerView
        factory.addEventListener(recyclerView, "scroll") { }
        factory.addEventListener(recyclerView, "endReached") { }

        factory.destroyView(recyclerView)

        assertNull(recyclerView.adapter)
        listOf(
            "childViews",
            "scrollHandlers",
            "endReachedHandlers",
            "scrollListeners",
            "firedEndReached",
            "stickyDecorations",
        ).forEach { fieldName ->
            val field = VSectionListFactory::class.java.getDeclaredField(fieldName)
            field.isAccessible = true
            val map = field.get(factory) as Map<*, *>
            assertFalse("$fieldName should release the destroyed view", map.containsKey(recyclerView))
        }
    }

    @Test
    fun stickySectionHeadersInstallsDecorationByDefaultAndCanBeDisabled() {
        val factory = VSectionListFactory()
        val recyclerView = factory.createView(context) as RecyclerView
        val decorations = (0 until recyclerView.itemDecorationCount).map { index ->
            recyclerView.getItemDecorationAt(index)
        }
        val decoration = decorations.filterIsInstance<StickySectionHeaderDecoration>().single()
        assertTrue(decoration.enabled)

        factory.updateProp(recyclerView, "stickySectionHeaders", false)
        assertFalse(decoration.enabled)

        factory.updateProp(recyclerView, "stickySectionHeaders", true)
        assertTrue(decoration.enabled)
        assertNotNull(recyclerView)
    }

    @Test
    fun stickyDecorationResolvesHeaderIndexFromInternalProp() {
        val headerA = View(context)
        val row = View(context)
        val headerB = View(context)
        StyleEngine.apply("__sectionHeader", true, headerA)
        StyleEngine.apply("__sectionHeader", true, headerB)

        val decoration = StickySectionHeaderDecoration(listOf(headerA, row, headerB, View(context)))
        assertEquals(0, decoration.headerIndexAtOrBefore(1))
        assertEquals(2, decoration.headerIndexAtOrBefore(3))
        assertEquals(2, decoration.nextHeaderIndexAfter(0))
        assertNull(decoration.nextHeaderIndexAfter(2))
        assertFalse(decoration.isSectionHeader(1))
        assertTrue(decoration.isSectionHeader(0))
    }
}
