package com.vuenative.core

import android.content.Context
import androidx.recyclerview.widget.RecyclerView
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
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
        ).forEach { fieldName ->
            val field = VSectionListFactory::class.java.getDeclaredField(fieldName)
            field.isAccessible = true
            val map = field.get(factory) as Map<*, *>
            assertFalse("$fieldName should release the destroyed view", map.containsKey(recyclerView))
        }
    }
}
