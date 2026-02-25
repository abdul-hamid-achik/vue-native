package com.vuenative.core

import android.content.Context
import android.os.Looper
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.test.core.app.ApplicationProvider
import com.google.android.flexbox.FlexboxLayout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NativeBridgeTest {

    private lateinit var context: Context
    private lateinit var bridge: NativeBridge

    @Before
    fun setUp() {
        // Reset ComponentRegistry singleton via reflection
        val crField = ComponentRegistry::class.java.getDeclaredField("instance")
        crField.isAccessible = true
        crField.set(null, null)

        // Reset NativeModuleRegistry singleton via reflection
        val nmrField = NativeModuleRegistry::class.java.getDeclaredField("instance")
        nmrField.isAccessible = true
        nmrField.set(null, null)

        context = ApplicationProvider.getApplicationContext()
        bridge = NativeBridge(context)

        // Set up a host container so setRootView can attach views
        val container = FrameLayout(context)
        bridge.hostContainer = container
    }

    @After
    fun tearDown() {
        bridge.clearAllRegistries()
    }

    private fun flush() {
        Shadows.shadowOf(Looper.getMainLooper()).idle()
    }

    // -------------------------------------------------------------------------
    // create
    // -------------------------------------------------------------------------

    @Test
    fun testCreate() {
        bridge.processOperations("""[{"op":"create","args":[1,"VView"]}]""")
        flush()

        assertNotNull("nodeViews[1] should exist", bridge.nodeViews[1])
        assertEquals("VView", bridge.nodeTypes[1])
        assertTrue("VView should create a FlexboxLayout", bridge.nodeViews[1] is FlexboxLayout)
    }

    // -------------------------------------------------------------------------
    // createText
    // -------------------------------------------------------------------------

    @Test
    fun testCreateText() {
        bridge.processOperations("""[{"op":"createText","args":[2,"Hello"]}]""")
        flush()

        assertNotNull("nodeViews[2] should exist", bridge.nodeViews[2])
        assertTrue("createText should produce VTextNodeView", bridge.nodeViews[2] is VTextNodeView)
        assertEquals("Hello", (bridge.nodeViews[2] as VTextNodeView).text.toString())
    }

    // -------------------------------------------------------------------------
    // appendChild
    // -------------------------------------------------------------------------

    @Test
    fun testAppendChild() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"create","args":[2,"VView"]},
            {"op":"appendChild","args":[1,2]}
        ]"""
        )
        flush()

        val parent = bridge.nodeViews[1] as ViewGroup
        val child = bridge.nodeViews[2]!!
        assertTrue("Child should be a child of parent", parent.indexOfChild(child) >= 0)
        assertEquals("nodeParents should track parent", 1, bridge.nodeParents[2])
        assertTrue("nodeChildren should track child", bridge.nodeChildren[1]?.contains(2) == true)
    }

    // -------------------------------------------------------------------------
    // removeChild
    // -------------------------------------------------------------------------

    @Test
    fun testRemoveChild() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"create","args":[2,"VView"]},
            {"op":"appendChild","args":[1,2]}
        ]"""
        )
        flush()

        // Verify child is attached
        val parent = bridge.nodeViews[1] as ViewGroup
        assertNotNull(bridge.nodeViews[2])
        assertTrue(parent.indexOfChild(bridge.nodeViews[2]!!) >= 0)

        // Remove child
        bridge.processOperations("""[{"op":"removeChild","args":[2]}]""")
        flush()

        assertFalse("nodeViews should not contain removed child", bridge.nodeViews.containsKey(2))
        assertNull("nodeParents should not contain removed child", bridge.nodeParents[2])
        assertEquals("Parent ViewGroup should have 0 children", 0, parent.childCount)
    }

    // -------------------------------------------------------------------------
    // insertBefore
    // -------------------------------------------------------------------------

    @Test
    fun testInsertBefore() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"create","args":[2,"VView"]},
            {"op":"create","args":[3,"VView"]},
            {"op":"appendChild","args":[1,2]},
            {"op":"insertBefore","args":[1,3,2]}
        ]"""
        )
        flush()

        val parent = bridge.nodeViews[1] as ViewGroup
        val child2 = bridge.nodeViews[2]!!
        val child3 = bridge.nodeViews[3]!!

        val idx2 = parent.indexOfChild(child2)
        val idx3 = parent.indexOfChild(child3)
        assertTrue("child3 should be before child2", idx3 < idx2)
        assertEquals("child3 should be at index 0", 0, idx3)
        assertEquals("child2 should be at index 1", 1, idx2)
    }

    // -------------------------------------------------------------------------
    // updateProp
    // -------------------------------------------------------------------------

    @Test
    fun testUpdateProp() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"updateProp","args":[1,"backgroundColor","#ff0000"]}
        ]"""
        )
        flush()

        val view = bridge.nodeViews[1]!!
        // After setting backgroundColor, the view should have a GradientDrawable background
        assertNotNull("View background should be set", view.background)
        assertTrue(
            "Background should be a GradientDrawable",
            view.background is android.graphics.drawable.GradientDrawable
        )
    }

    // -------------------------------------------------------------------------
    // updateStyle
    // -------------------------------------------------------------------------

    @Test
    fun testUpdateStyle() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"updateStyle","args":[1,{"opacity":0.5}]}
        ]"""
        )
        flush()

        val view = bridge.nodeViews[1]!!
        assertEquals("alpha should be 0.5", 0.5f, view.alpha, 0.01f)
    }

    // -------------------------------------------------------------------------
    // setText
    // -------------------------------------------------------------------------

    @Test
    fun testSetText() {
        bridge.processOperations(
            """[
            {"op":"createText","args":[1,"Hello"]},
            {"op":"setText","args":[1,"World"]}
        ]"""
        )
        flush()

        val textView = bridge.nodeViews[1] as VTextNodeView
        assertEquals("World", textView.text.toString())
    }

    // -------------------------------------------------------------------------
    // addEventListener
    // -------------------------------------------------------------------------

    @Test
    fun testAddEventListener() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"addEventListener","args":[1,"press"]}
        ]"""
        )
        flush()

        assertTrue(
            "eventHandlers should have entry for '1:press'",
            bridge.eventHandlers.containsKey("1:press")
        )
    }

    // -------------------------------------------------------------------------
    // removeEventListener
    // -------------------------------------------------------------------------

    @Test
    fun testRemoveEventListener() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"addEventListener","args":[1,"press"]},
            {"op":"removeEventListener","args":[1,"press"]}
        ]"""
        )
        flush()

        assertFalse(
            "eventHandlers should not have entry for '1:press'",
            bridge.eventHandlers.containsKey("1:press")
        )
    }

    // -------------------------------------------------------------------------
    // setRootView
    // -------------------------------------------------------------------------

    @Test
    fun testSetRootView() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"setRootView","args":[1]}
        ]"""
        )
        flush()

        assertNotNull("rootView should be set", bridge.rootView)
        assertEquals("rootView should be nodeViews[1]", bridge.nodeViews[1], bridge.rootView)
        assertEquals(
            "hostContainer should have 1 child",
            1,
            bridge.hostContainer!!.childCount
        )
    }

    // -------------------------------------------------------------------------
    // clearAllRegistries
    // -------------------------------------------------------------------------

    @Test
    fun testClearAllRegistries() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"create","args":[2,"VView"]},
            {"op":"appendChild","args":[1,2]}
        ]"""
        )
        flush()

        // Verify state exists
        assertTrue(bridge.nodeViews.isNotEmpty())
        assertTrue(bridge.nodeTypes.isNotEmpty())
        assertTrue(bridge.nodeParents.isNotEmpty())
        assertTrue(bridge.nodeChildren.isNotEmpty())

        bridge.clearAllRegistries()

        assertTrue("nodeViews should be empty", bridge.nodeViews.isEmpty())
        assertTrue("nodeTypes should be empty", bridge.nodeTypes.isEmpty())
        assertTrue("eventHandlers should be empty", bridge.eventHandlers.isEmpty())
        assertTrue("nodeParents should be empty", bridge.nodeParents.isEmpty())
        assertTrue("nodeChildren should be empty", bridge.nodeChildren.isEmpty())
        assertNull("rootView should be null", bridge.rootView)
    }

    // -------------------------------------------------------------------------
    // fireEvent
    // -------------------------------------------------------------------------

    @Test
    fun testFireEvent() {
        var capturedNodeId = -1
        var capturedEventName = ""
        var capturedPayloadJson = ""

        bridge.onFireEvent = { nodeId, eventName, payloadJson ->
            capturedNodeId = nodeId
            capturedEventName = eventName
            capturedPayloadJson = payloadJson
        }

        bridge.fireEvent(42, "press", mapOf("x" to 10, "y" to 20))

        assertEquals(42, capturedNodeId)
        assertEquals("press", capturedEventName)
        assertTrue(
            "Payload should contain x and y",
            capturedPayloadJson.contains("\"x\"") && capturedPayloadJson.contains("\"y\"")
        )
    }

    // -------------------------------------------------------------------------
    // dispatchGlobalEvent
    // -------------------------------------------------------------------------

    @Test
    fun testDispatchGlobalEvent() {
        var capturedEventName = ""
        var capturedPayloadJson = ""

        bridge.onDispatchGlobalEvent = { eventName, payloadJson ->
            capturedEventName = eventName
            capturedPayloadJson = payloadJson
        }

        bridge.dispatchGlobalEvent("networkChange", mapOf("connected" to "true"))

        assertEquals("networkChange", capturedEventName)
        assertTrue(
            "Payload should contain connected",
            capturedPayloadJson.contains("\"connected\"")
        )
    }

    // -------------------------------------------------------------------------
    // invalidJson
    // -------------------------------------------------------------------------

    @Test
    fun testInvalidJson() {
        // Should not crash
        bridge.processOperations("this is not json")
        flush()

        // Verify bridge still works after invalid JSON
        bridge.processOperations("""[{"op":"create","args":[1,"VView"]}]""")
        flush()
        assertNotNull(bridge.nodeViews[1])
    }

    // -------------------------------------------------------------------------
    // unknownOperation
    // -------------------------------------------------------------------------

    @Test
    fun testUnknownOperation() {
        // Should not crash
        bridge.processOperations("""[{"op":"unknown","args":[]}]""")
        flush()

        // Verify bridge still works after unknown operation
        bridge.processOperations("""[{"op":"create","args":[1,"VView"]}]""")
        flush()
        assertNotNull(bridge.nodeViews[1])
    }

    // -------------------------------------------------------------------------
    // cleanupNode
    // -------------------------------------------------------------------------

    @Test
    fun testCleanupNode() {
        // Create a parent with a child, child has a grandchild
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"create","args":[2,"VView"]},
            {"op":"create","args":[3,"VView"]},
            {"op":"appendChild","args":[1,2]},
            {"op":"appendChild","args":[2,3]},
            {"op":"addEventListener","args":[3,"press"]}
        ]"""
        )
        flush()

        // Verify everything exists
        assertNotNull(bridge.nodeViews[2])
        assertNotNull(bridge.nodeViews[3])
        assertTrue(bridge.eventHandlers.containsKey("3:press"))

        // Remove child 2 (which should also clean up grandchild 3)
        bridge.processOperations("""[{"op":"removeChild","args":[2]}]""")
        flush()

        assertFalse("nodeViews should not contain child 2", bridge.nodeViews.containsKey(2))
        assertFalse("nodeViews should not contain grandchild 3", bridge.nodeViews.containsKey(3))
        assertFalse("nodeTypes should not contain child 2", bridge.nodeTypes.containsKey(2))
        assertFalse("nodeTypes should not contain grandchild 3", bridge.nodeTypes.containsKey(3))
        assertFalse("eventHandlers for grandchild should be cleaned up", bridge.eventHandlers.containsKey("3:press"))
        assertNull("nodeParents for child 2 should be null", bridge.nodeParents[2])
        assertNull("nodeParents for grandchild 3 should be null", bridge.nodeParents[3])
    }
}
