package com.vuenative.core

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import org.json.JSONObject
import org.junit.Assert.assertEquals
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
class InspectorModuleTest {
    private lateinit var context: Context
    private lateinit var bridge: NativeBridge
    private lateinit var module: InspectorModule

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        bridge = NativeBridge(context).also { it.hostContainer = FrameLayout(context) }
        module = InspectorModule().also { it.initialize(context, bridge) }
    }

    /** Invoke dumpTree and return the serialized tree (null when the registry is empty). */
    private fun dump(): JSONObject? {
        var result: Any? = "sentinel"
        var error: String? = "not_called"
        module.invoke("dumpTree", emptyList(), bridge) { value, err ->
            result = value
            error = err
        }
        assertNull("dumpTree should not error", error)
        return result as? JSONObject
    }

    @Test
    fun moduleIsNamedInspector() {
        assertEquals("Inspector", module.moduleName)
    }

    @Test
    fun dumpTreeSerializesSingleNodeWithFrame() {
        val root = FrameLayout(context)
        root.layout(0, 0, 200, 100)
        bridge.nodeViews[1] = root
        bridge.nodeTypes[1] = "VView"
        bridge.rootView = root

        val tree = dump()
        assertNotNull(tree)
        assertEquals(1, tree!!.getInt("id"))
        assertEquals("VView", tree.getString("type"))

        val frame = tree.getJSONObject("frame")
        assertEquals(0, frame.getInt("x"))
        assertEquals(0, frame.getInt("y"))
        assertEquals(200, frame.getInt("width"))
        assertEquals(100, frame.getInt("height"))

        assertEquals(0, tree.getJSONArray("children").length())
    }

    @Test
    fun dumpTreeNestsChildrenWithTypesAndFrames() {
        val root = FrameLayout(context)
        root.layout(0, 0, 300, 300)
        val child = TextView(context)
        // left=10, top=20, right=60, bottom=70 -> width=50, height=50
        child.layout(10, 20, 60, 70)

        bridge.nodeViews[1] = root
        bridge.nodeTypes[1] = "VView"
        bridge.nodeViews[2] = child
        bridge.nodeTypes[2] = "VText"
        bridge.nodeChildren[1] = mutableListOf(2)
        bridge.nodeParents[2] = 1
        bridge.rootView = root

        val tree = dump()
        assertNotNull(tree)

        val children = tree!!.getJSONArray("children")
        assertEquals(1, children.length())

        val childNode = children.getJSONObject(0)
        assertEquals(2, childNode.getInt("id"))
        assertEquals("VText", childNode.getString("type"))

        val frame = childNode.getJSONObject("frame")
        assertEquals(10, frame.getInt("x"))
        assertEquals(20, frame.getInt("y"))
        assertEquals(50, frame.getInt("width"))
        assertEquals(50, frame.getInt("height"))
    }

    @Test
    fun dumpTreeEmptyRegistryReturnsNull() {
        assertNull(dump())
    }

    @Test
    fun dumpTreeFallsBackToParentlessNodeWithoutRootView() {
        val view = View(context)
        view.layout(0, 0, 5, 5)
        bridge.nodeViews[7] = view
        bridge.nodeTypes[7] = "VView"
        // No rootView set — the dump should still root at the parentless node.
        val tree = dump()
        assertNotNull(tree)
        assertEquals(7, tree!!.getInt("id"))
    }

    @Test
    fun unknownMethodReturnsError() {
        var error: String? = null
        module.invoke("bogus", emptyList(), bridge) { _, err -> error = err }
        assertNotNull(error)
        assertTrue(error!!.contains("bogus"))
    }
}
