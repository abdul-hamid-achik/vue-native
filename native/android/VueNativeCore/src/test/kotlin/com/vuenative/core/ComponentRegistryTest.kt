package com.vuenative.core

import android.content.Context
import android.view.View
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import com.google.android.flexbox.FlexboxLayout
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
class ComponentRegistryTest {

    private lateinit var context: Context
    private lateinit var registry: ComponentRegistry

    @Before
    fun setUp() {
        // Reset singleton via reflection for test isolation
        val field = ComponentRegistry::class.java.getDeclaredField("instance")
        field.isAccessible = true
        field.set(null, null)

        context = ApplicationProvider.getApplicationContext()
        registry = ComponentRegistry.getInstance(context)
    }

    // -------------------------------------------------------------------------
    // All 28 default component types should be registered
    // -------------------------------------------------------------------------

    @Test
    fun testAllComponentsRegistered() {
        val expectedTypes = listOf(
            "VView", "VText", "VButton", "VInput", "VSwitch",
            "VActivityIndicator", "VScrollView", "VImage",
            "VKeyboardAvoiding", "VSafeArea", "VSlider", "VList",
            "VModal", "VAlertDialog", "VStatusBar", "VWebView",
            "VProgressBar", "VPicker", "VSegmentedControl", "VActionSheet",
            "VRefreshControl", "VPressable", "VSectionList", "VCheckbox",
            "VRadio", "VDropdown", "VVideo", "__ROOT__"
        )

        for (type in expectedTypes) {
            val view = registry.createView(type)
            assertNotNull("createView('$type') should return non-null", view)
        }
    }

    // -------------------------------------------------------------------------
    // Unknown type returns null
    // -------------------------------------------------------------------------

    @Test
    fun testUnknownTypeReturnsNull() {
        val view = registry.createView("NonExistent")
        assertNull("Unknown type should return null", view)
    }

    // -------------------------------------------------------------------------
    // Factory is stored on view via tag
    // -------------------------------------------------------------------------

    @Test
    fun testFactoryStoredOnView() {
        val view = registry.createView("VView")!!
        val factory = registry.factoryForView(view)
        assertNotNull("factoryForView should return non-null after createView", factory)
    }

    // -------------------------------------------------------------------------
    // factoryForType
    // -------------------------------------------------------------------------

    @Test
    fun testFactoryForType() {
        val factory = registry.factoryForType("VView")
        assertNotNull("factoryForType('VView') should return non-null", factory)
        assertTrue("VView factory should be VViewFactory", factory is VViewFactory)
    }

    @Test
    fun testFactoryForTypeUnknown() {
        val factory = registry.factoryForType("NonExistent")
        assertNull("factoryForType for unknown type should return null", factory)
    }

    // -------------------------------------------------------------------------
    // Register a custom factory
    // -------------------------------------------------------------------------

    @Test
    fun testRegisterCustomFactory() {
        val customFactory = object : NativeComponentFactory {
            override fun createView(context: Context): View = View(context)
            override fun updateProp(view: View, key: String, value: Any?) {}
            override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {}
            override fun removeEventListener(view: View, event: String) {}
        }

        registry.register("CustomComponent", customFactory)
        val view = registry.createView("CustomComponent")
        assertNotNull("Custom component should be created", view)

        val retrievedFactory = registry.factoryForType("CustomComponent")
        assertEquals("Retrieved factory should be the custom factory", customFactory, retrievedFactory)
    }

    // -------------------------------------------------------------------------
    // VText creates a TextView
    // -------------------------------------------------------------------------

    @Test
    fun testVTextCreatesTextView() {
        val view = registry.createView("VText")
        assertNotNull(view)
        assertTrue("VText should create a TextView", view is TextView)
    }

    // -------------------------------------------------------------------------
    // VView creates a FlexboxLayout
    // -------------------------------------------------------------------------

    @Test
    fun testVViewCreatesFlexboxLayout() {
        val view = registry.createView("VView")
        assertNotNull(view)
        assertTrue("VView should create a FlexboxLayout", view is FlexboxLayout)
    }

    // -------------------------------------------------------------------------
    // Singleton behavior
    // -------------------------------------------------------------------------

    @Test
    fun testSingletonReturnsSameInstance() {
        val instance1 = ComponentRegistry.getInstance(context)
        val instance2 = ComponentRegistry.getInstance(context)
        assertTrue("getInstance should return the same instance", instance1 === instance2)
    }

    // -------------------------------------------------------------------------
    // Register overwrites existing factory
    // -------------------------------------------------------------------------

    @Test
    fun testRegisterOverwritesExistingFactory() {
        val customFactory = object : NativeComponentFactory {
            override fun createView(context: Context): View = TextView(context)
            override fun updateProp(view: View, key: String, value: Any?) {}
            override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {}
            override fun removeEventListener(view: View, event: String) {}
        }

        // Overwrite the default VView factory
        registry.register("VView", customFactory)

        val factory = registry.factoryForType("VView")
        assertEquals("Factory should be the newly registered one", customFactory, factory)

        // The view created should now be a TextView (from custom factory), not FlexboxLayout
        val view = registry.createView("VView")
        assertTrue("Overwritten VView should create a TextView", view is TextView)
    }
}
