package com.vuenative.core

import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Color
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NativeBridgeHostContextTest {
    private lateinit var activityController: ActivityController<AppCompatActivity>
    private lateinit var activity: AppCompatActivity
    private lateinit var bridge: NativeBridge

    @Before
    fun setUp() {
        val registryField = ComponentRegistry::class.java.getDeclaredField("instance")
        registryField.isAccessible = true
        registryField.set(null, null)

        activityController = Robolectric.buildActivity(AppCompatActivity::class.java)
        activity = activityController.get()
        activity.setTheme(androidx.appcompat.R.style.Theme_AppCompat)
        activityController.create().start().resume()

        bridge = NativeBridge(activity).also {
            it.hostContainer = FrameLayout(activity)
        }
    }

    @After
    fun tearDown() {
        bridge.destroyHost()
        activityController.pause().stop().destroy()
    }

    @Test
    fun bridgeCreatedViewsUseTheHostActivityContext() {
        bridge.processOperations("""[{"op":"create","args":[1,"VView"]}]""")
        flushMainLooper()

        assertSame(activity, bridge.nodeViews[1]?.context)
    }

    @Test
    fun bridgeCreatedModalUsesTheHostWindowContext() {
        bridge.processOperations(
            """[
                {"op":"create","args":[1,"VModal"]},
                {"op":"updateProp","args":[1,"visible",true]}
            ]""",
        )
        flushMainLooper()

        val placeholder = bridge.nodeViews[1]
        assertNotNull(placeholder)
        assertSame(activity, placeholder?.context)

        val factory = ComponentRegistry.getInstance(activity).factoryForView(placeholder as View) as VModalFactory
        val dialog = stateMap(factory, "dialogs")[placeholder] as? Dialog
        assertNotNull("A modal created through NativeBridge should be able to attach to the host window", dialog)
        assertSame(activity, dialog?.context?.hostActivity())
        assertTrue(dialog?.isShowing == true)
    }

    @Test
    @Suppress("DEPRECATION")
    fun bridgeCreatedStatusBarUpdatesTheHostWindow() {
        activity.window.statusBarColor = Color.BLACK

        bridge.processOperations(
            """[
                {"op":"create","args":[1,"VStatusBar"]},
                {"op":"updateProp","args":[1,"backgroundColor","#123456"]}
            ]""",
        )
        flushMainLooper()

        assertSame(activity, bridge.nodeViews[1]?.context)
        assertEquals(Color.rgb(0x12, 0x34, 0x56), activity.window.statusBarColor)
    }

    private fun flushMainLooper() {
        shadowOf(Looper.getMainLooper()).idle()
    }

    private fun stateMap(factory: VModalFactory, fieldName: String): Map<*, *> {
        val field = VModalFactory::class.java.getDeclaredField(fieldName)
        field.isAccessible = true
        return field.get(factory) as Map<*, *>
    }

    private fun Context.hostActivity(): Activity? {
        var current = this
        while (current is ContextWrapper) {
            if (current is Activity) return current
            val baseContext = current.baseContext
            if (baseContext === current) return null
            current = baseContext
        }
        return current as? Activity
    }
}
