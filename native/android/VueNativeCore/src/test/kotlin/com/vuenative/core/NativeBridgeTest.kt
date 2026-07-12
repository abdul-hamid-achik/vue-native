package com.vuenative.core

import android.content.Context
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.recyclerview.widget.RecyclerView
import androidx.test.core.app.ApplicationProvider
import com.google.android.flexbox.FlexboxLayout
import org.json.JSONObject
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

    @Test
    fun testRemovingRootDetachesTheModalHost() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"__ROOT__"]},
            {"op":"setRootView","args":[1]},
            {"op":"removeChild","args":[1]}
        ]"""
        )
        flush()

        assertNull(bridge.rootView)
        assertEquals(0, bridge.hostContainer?.childCount)
        assertFalse(bridge.nodeViews.containsKey(1))
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

    @Test
    fun testInsertBeforeMovesExistingChildWithoutDuplicatingIt() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"create","args":[2,"VView"]},
            {"op":"create","args":[3,"VView"]},
            {"op":"create","args":[4,"VView"]},
            {"op":"appendChild","args":[1,2]},
            {"op":"appendChild","args":[1,3]},
            {"op":"appendChild","args":[1,4]},
            {"op":"insertBefore","args":[1,4,2]}
        ]"""
        )
        flush()

        val parent = bridge.nodeViews[1] as ViewGroup
        assertEquals(3, parent.childCount)
        assertEquals(bridge.nodeViews[4], parent.getChildAt(0))
        assertEquals(bridge.nodeViews[2], parent.getChildAt(1))
        assertEquals(bridge.nodeViews[3], parent.getChildAt(2))
        assertEquals(listOf(4, 2, 3), bridge.nodeChildren[1])
    }

    @Test
    fun testInsertBeforeSelfLeavesTheChildOrderUnchanged() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"create","args":[2,"VView"]},
            {"op":"create","args":[3,"VView"]},
            {"op":"appendChild","args":[1,2]},
            {"op":"appendChild","args":[1,3]},
            {"op":"insertBefore","args":[1,2,2]}
        ]"""
        )
        flush()

        val parent = bridge.nodeViews[1] as ViewGroup
        assertEquals(listOf(2, 3), bridge.nodeChildren[1])
        assertEquals(bridge.nodeViews[2], parent.getChildAt(0))
        assertEquals(bridge.nodeViews[3], parent.getChildAt(1))
    }

    @Test
    fun testAppendChildReparentsAndCleansOldIndexes() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VView"]},
            {"op":"create","args":[2,"VView"]},
            {"op":"create","args":[3,"VView"]},
            {"op":"appendChild","args":[1,3]},
            {"op":"appendChild","args":[2,3]}
        ]"""
        )
        flush()

        val firstParent = bridge.nodeViews[1] as ViewGroup
        val secondParent = bridge.nodeViews[2] as ViewGroup
        val child = bridge.nodeViews[3]
        assertEquals(0, firstParent.childCount)
        assertEquals(1, secondParent.childCount)
        assertEquals(child, secondParent.getChildAt(0))
        assertEquals(2, bridge.nodeParents[3])
        assertFalse(bridge.nodeChildren[1]?.contains(3) == true)
        assertEquals(listOf(3), bridge.nodeChildren[2])

        // Removing the former parent must not clean up a node that was moved.
        bridge.processOperations("""[{"op":"removeChild","args":[1]}]""")
        flush()
        assertNotNull(bridge.nodeViews[3])
        assertEquals(2, bridge.nodeParents[3])
    }

    @Test
    fun testRecyclerBackedListsUseLogicalChildIndexesForMoves() {
        assertLogicalListMove("VList", VListFactory::class.java)
        assertLogicalListMove("VSectionList", VSectionListFactory::class.java)
    }

    private fun assertLogicalListMove(type: String, factoryClass: Class<*>) {
        bridge.processOperations(
            """[
            {"op":"create","args":[10,"$type"]},
            {"op":"create","args":[11,"VView"]},
            {"op":"create","args":[12,"VView"]},
            {"op":"create","args":[13,"VView"]},
            {"op":"appendChild","args":[10,11]},
            {"op":"appendChild","args":[10,12]},
            {"op":"appendChild","args":[10,13]},
            {"op":"insertBefore","args":[10,13,11]}
        ]"""
        )
        flush()

        val list = bridge.nodeViews[10] as RecyclerView
        assertEquals(3, list.adapter?.itemCount)
        assertEquals(listOf(13, 11, 12), bridge.nodeChildren[10])

        val factory = ComponentRegistry.getInstance(context).factoryForView(list)!!
        val field = factoryClass.getDeclaredField("childViews")
        field.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val rows = (field.get(factory) as Map<RecyclerView, MutableList<View>>)[list]!!
        assertEquals(
            listOf(bridge.nodeViews[13], bridge.nodeViews[11], bridge.nodeViews[12]),
            rows,
        )

        bridge.clearAllRegistries()
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

    @Test
    fun testTextChildChangesReorderAndRemovalRefreshVTextParent() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VText"]},
            {"op":"createText","args":[2,"Hello"]},
            {"op":"createText","args":[3," World"]},
            {"op":"appendChild","args":[1,2]},
            {"op":"appendChild","args":[1,3]}
        ]"""
        )
        flush()

        val label = bridge.nodeViews[1] as android.widget.TextView
        assertEquals("Hello World", label.text.toString())

        bridge.processOperations("""[{"op":"setText","args":[2,"Goodbye"]}]""")
        flush()
        assertEquals("Goodbye World", label.text.toString())

        bridge.processOperations("""[{"op":"insertBefore","args":[1,3,2]}]""")
        flush()
        assertEquals(" WorldGoodbye", label.text.toString())

        bridge.processOperations("""[{"op":"removeChild","args":[2]}]""")
        flush()
        assertEquals(" World", label.text.toString())
    }

    @Test
    fun testNestedVTextElementTextUpdateRefreshesAncestor() {
        bridge.processOperations(
            """[
            {"op":"create","args":[1,"VText"]},
            {"op":"create","args":[2,"VText"]},
            {"op":"setElementText","args":[2,"Hello"]},
            {"op":"appendChild","args":[1,2]}
        ]"""
        )
        flush()

        val outerLabel = bridge.nodeViews[1] as android.widget.TextView
        assertEquals("Hello", outerLabel.text.toString())

        bridge.processOperations("""[{"op":"setElementText","args":[2,"Goodbye"]}]""")
        flush()
        assertEquals("Goodbye", outerLabel.text.toString())
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
        val hostContainer = bridge.hostContainer!!
        assertEquals(
            "hostContainer should have root view plus modal container",
            2,
            hostContainer.childCount
        )
        assertEquals("First child should be the root view", bridge.rootView, hostContainer.getChildAt(0))
        assertTrue("Second child should be a modal FrameLayout", hostContainer.getChildAt(1) is FrameLayout)
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

    @Test
    fun testNativeModuleArgsUseRecursiveKotlinCollections() {
        var capturedArgs: List<Any?>? = null
        val module = object : NativeModule {
            override val moduleName = "ArgumentCapture"

            override fun invoke(
                method: String,
                args: List<Any?>,
                bridge: NativeBridge,
                callback: (result: Any?, error: String?) -> Unit,
            ) {
                capturedArgs = args
                callback(true, null)
            }
        }
        NativeModuleRegistry.getInstance(context).register(module)

        bridge.processOperations(
            """[{"op":"invokeNativeModule","args":["ArgumentCapture","capture",[{"title":"Hello","options":{"enabled":true,"count":2},"items":["one",{"id":3},null]}],7]}]""",
        )
        flush()

        val root = capturedArgs?.single() as? Map<*, *>
        assertNotNull("Object args should become Kotlin maps", root)
        assertEquals("Hello", root?.get("title"))
        assertEquals(mapOf("enabled" to true, "count" to 2), root?.get("options"))
        assertEquals(listOf("one", mapOf("id" to 3), null), root?.get("items"))
    }

    @Test
    fun testHotReloadIgnoresStaleNativeCallbackWhenIdIsReused() {
        val pendingCallbacks = mutableListOf<(Any?, String?) -> Unit>()
        val module = object : NativeModule {
            override val moduleName = "DelayedCallback"

            override fun invoke(
                method: String,
                args: List<Any?>,
                bridge: NativeBridge,
                callback: (result: Any?, error: String?) -> Unit,
            ) {
                pendingCallbacks.add(callback)
            }
        }
        NativeModuleRegistry.getInstance(context).register(module)

        val resolvedValues = mutableListOf<String>()
        bridge.onFireEvent = { nodeId, eventName, payloadJson ->
            if (nodeId == -1 && eventName == "__callback__") {
                resolvedValues.add(JSONObject(payloadJson).getString("result"))
            }
        }

        bridge.processOperations(
            """[{"op":"invokeNativeModule","args":["DelayedCallback","wait",[],1]}]""",
        )
        flush()

        bridge.clearAllRegistries()
        bridge.processOperations(
            """[{"op":"invokeNativeModule","args":["DelayedCallback","wait",[],1]}]""",
        )
        flush()

        assertEquals(2, pendingCallbacks.size)
        pendingCallbacks[0]("stale", null)
        pendingCallbacks[1]("current", null)
        flush()

        assertEquals(listOf("current"), resolvedValues)
    }

    @Test
    fun testDestroyHostCancelsQueuedOperationsAndReleasesNativeState() {
        val staleBridge = NativeBridge(context)
        val staleContainer = FrameLayout(context)
        staleBridge.hostContainer = staleContainer

        // Leave the operation queued on the main handler, then destroy the
        // owning Activity/bridge before that batch can run.
        staleBridge.processOperations("""[{"op":"create","args":[99,"VView"]}]""")
        staleBridge.destroyHost()
        flush()

        assertFalse(staleBridge.nodeViews.containsKey(99))
        assertTrue(staleBridge.nodeParents.isEmpty())
        assertTrue(staleBridge.nodeChildren.isEmpty())
        assertNull(staleBridge.rootView)
        assertNull(staleBridge.hostContainer)
        assertEquals(0, staleContainer.childCount)

        // Once detached, future batches from a late JS callback are ignored.
        staleBridge.processOperations("""[{"op":"create","args":[100,"VView"]}]""")
        flush()
        assertFalse(staleBridge.nodeViews.containsKey(100))
    }

    @Test
    fun testClearAllRegistriesDetachesAndClearsTeleportState() {
        bridge.processOperations(
            """[
                {"op":"create","args":[1,"VView"]},
                {"op":"createTeleport","args":[1,10,11]}
            ]""",
        )
        flush()

        val parent = bridge.nodeViews[1] as ViewGroup
        assertEquals(1, parent.childCount)

        bridge.clearAllRegistries()

        assertEquals(0, parent.childCount)
        for (fieldName in listOf("teleportContainers", "teleportMarkers")) {
            val field = NativeBridge::class.java.getDeclaredField(fieldName)
            field.isAccessible = true
            assertTrue((field.get(bridge) as Map<*, *>).isEmpty())
        }
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
