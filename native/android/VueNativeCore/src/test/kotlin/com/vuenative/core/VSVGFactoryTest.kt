package com.vuenative.core

import android.content.Context
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
class VSVGFactoryTest {

    private lateinit var context: Context
    private lateinit var factory: VSVGFactory
    private lateinit var view: SVGView

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        factory = VSVGFactory()
        view = factory.createView(context) as SVGView
    }

    @Test
    fun createViewReturnsSVGView() {
        assertNotNull("VSVGFactory should create a view", view)
    }

    @Test
    fun validInlineSvgFiresLoadAndRenders() {
        var loadCount = 0
        var errorPayload: Any? = null
        factory.addEventListener(view, "load") { loadCount += 1 }
        factory.addEventListener(view, "error") { errorPayload = it }

        factory.updateProp(view, "source", mapOf("svg" to VALID_SVG))

        assertEquals("load should fire once for valid SVG", 1, loadCount)
        assertNull("error must not fire for valid SVG", errorPayload)
        assertTrue("view should hold a rendered picture", view.hasPicture())
    }

    @Test
    fun invalidInlineSvgFiresErrorNotLoad() {
        var loadCount = 0
        var errorPayload: Any? = null
        factory.addEventListener(view, "load") { loadCount += 1 }
        factory.addEventListener(view, "error") { errorPayload = it }

        factory.updateProp(view, "source", mapOf("svg" to "this is not svg <<<"))

        assertEquals("load must not fire for invalid SVG", 0, loadCount)
        assertNotNull("error must fire for invalid SVG", errorPayload)
        assertFalse("view should not hold a picture", view.hasPicture())
    }

    @Test
    fun emptySourceClearsWithoutEventsOrCrash() {
        var loadCount = 0
        var errorCount = 0
        factory.addEventListener(view, "load") { loadCount += 1 }
        factory.addEventListener(view, "error") { errorCount += 1 }

        factory.updateProp(view, "source", mapOf<String, Any?>())
        factory.updateProp(view, "source", null)

        assertEquals(0, loadCount)
        assertEquals(0, errorCount)
        assertFalse("empty source should leave no picture", view.hasPicture())
    }

    @Test
    fun missingAssetFiresErrorNotLoad() {
        var loadCount = 0
        var errorPayload: Any? = null
        factory.addEventListener(view, "load") { loadCount += 1 }
        factory.addEventListener(view, "error") { errorPayload = it }

        factory.updateProp(view, "source", mapOf("asset" to "no_such_icon.svg"))

        assertEquals("load must not fire for a missing asset", 0, loadCount)
        assertNotNull("error must fire for a missing asset", errorPayload)
        assertFalse(view.hasPicture())
    }

    @Test
    fun tintColorAppliesWithoutCrash() {
        factory.updateProp(view, "source", mapOf("svg" to VALID_SVG))

        // Valid hex applies a tint; invalid color keeps previous state. Neither throws.
        factory.updateProp(view, "tintColor", "#ff0000")
        factory.updateProp(view, "tintColor", "not-a-color")
        factory.updateProp(view, "tintColor", null)

        assertTrue("picture should survive tint updates", view.hasPicture())
    }

    @Test
    fun removingLoadListenerStopsCallbacks() {
        var loadCount = 0
        factory.addEventListener(view, "load") { loadCount += 1 }
        factory.removeEventListener(view, "load")

        factory.updateProp(view, "source", mapOf("svg" to VALID_SVG))

        assertEquals("removed listener must not be invoked", 0, loadCount)
    }

    @Test
    fun destroyViewClearsPictureAndHandlers() {
        var loadCount = 0
        factory.addEventListener(view, "load") { loadCount += 1 }
        factory.updateProp(view, "source", mapOf("svg" to VALID_SVG))
        assertEquals(1, loadCount)

        factory.destroyView(view)

        assertFalse("picture should be cleared on destroy", view.hasPicture())
        // Handlers are dropped: a later source change must not invoke them.
        factory.updateProp(view, "source", mapOf("svg" to VALID_SVG))
        assertEquals(1, loadCount)
    }

    private companion object {
        const val VALID_SVG = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" width=\"24\" height=\"24\">" +
            "<rect x=\"0\" y=\"0\" width=\"24\" height=\"24\" fill=\"#ff0000\"/></svg>"
    }
}
