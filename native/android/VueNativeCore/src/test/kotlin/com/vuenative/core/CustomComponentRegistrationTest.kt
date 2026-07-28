package com.vuenative.core

import android.content.Context
import android.view.View
import android.widget.TextView
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

private class DummyFactory : NativeComponentFactory {
    override fun createView(context: Context): View = TextView(context)
    override fun updateProp(view: View, key: String, value: Any?) {}
    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {}
    override fun removeEventListener(view: View, event: String) {}
}

private class RegistrationTestActivity : VueNativeActivity() {
    override fun getBundleAssetPath(): String = "missing-test-bundle.js"
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class CustomComponentRegistrationTest {

    @Before
    fun setUp() {
        // Reset the process-wide singleton for test isolation.
        val componentRegistry = ComponentRegistry::class.java.getDeclaredField("instance")
        componentRegistry.isAccessible = true
        componentRegistry.set(null, null)
    }

    @Test
    fun registerComponentExposesCustomFactoryToRegistry() {
        val activity = Robolectric.buildActivity(RegistrationTestActivity::class.java).get()
        val factory = DummyFactory()

        activity.registerComponent("MyChart", factory)

        val registry = ComponentRegistry.getInstance(activity)
        assertSame(factory, registry.factoryForType("MyChart"))

        val view = registry.createView("MyChart")
        assertNotNull("Registered custom component should create a view", view)
        assertTrue("Custom factory should produce its view type", view is TextView)
        assertSame("Created view should be tagged with its factory", factory, registry.factoryForView(view!!))
    }

    @Test
    fun registerComponentOverridesExistingType() {
        val activity = Robolectric.buildActivity(RegistrationTestActivity::class.java).get()
        val factory = DummyFactory()

        activity.registerComponent("VView", factory)

        val registry = ComponentRegistry.getInstance(activity)
        assertEquals(factory, registry.factoryForType("VView"))
        assertTrue("Overridden VView should now use the custom factory", registry.createView("VView") is TextView)
    }
}
