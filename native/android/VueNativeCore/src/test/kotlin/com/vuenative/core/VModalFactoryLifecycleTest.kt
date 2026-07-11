package com.vuenative.core

import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.content.DialogInterface
import android.os.Looper
import android.view.View
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
class VModalFactoryLifecycleTest {
    private lateinit var activityController: ActivityController<Activity>
    private lateinit var activity: Activity

    @Before
    fun setUp() {
        activityController = Robolectric.buildActivity(Activity::class.java).setup()
        activity = activityController.get()
    }

    @After
    fun tearDown() {
        activityController.pause().stop().destroy()
    }

    @Test
    fun destroyViewDismissesSilentlyAndReleasesAllViewReferences() {
        val factory = VModalFactory()
        val placeholder = factory.createView(activity)
        var dismissCount = 0
        factory.addEventListener(placeholder, "dismiss") { dismissCount += 1 }
        factory.updateProp(placeholder, "visible", true)

        val dialog = stateMap(factory, "dialogs")[placeholder] as Dialog
        assertTrue(dialog.isShowing)

        factory.destroyView(placeholder)
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(0, dismissCount)
        assertFalse(dialog.isShowing)
        assertViewReleased(factory, placeholder)

        factory.destroyView(placeholder)
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(0, dismissCount)
        assertViewReleased(factory, placeholder)
    }

    @Test
    fun destroyViewDetachesListenerBeforeSynchronousDismiss() {
        val factory = VModalFactory()
        val placeholder = factory.createView(activity)
        var dismissCount = 0
        factory.addEventListener(placeholder, "dismiss") { dismissCount += 1 }
        val dismissHandlers = mutableStateMap<View, (Any?) -> Unit>(factory, "dismissHandlers")
        val dialog = SynchronousDismissDialog(activity).apply {
            setOnDismissListener { dismissHandlers[placeholder]?.invoke(null) }
        }
        mutableStateMap<View, Dialog>(factory, "dialogs")[placeholder] = dialog

        factory.destroyView(placeholder)

        assertEquals(0, dismissCount)
        assertTrue(dialog.listenerWasClearedBeforeDismiss)
        assertFalse(dialog.isShowing)
        assertViewReleased(factory, placeholder)
    }

    @Test
    fun settingVisibleFalseStillEmitsDismissEvent() {
        val factory = VModalFactory()
        val placeholder = factory.createView(activity)
        var dismissCount = 0
        factory.addEventListener(placeholder, "dismiss") { dismissCount += 1 }
        factory.updateProp(placeholder, "visible", true)

        factory.updateProp(placeholder, "visible", false)
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(1, dismissCount)
        factory.destroyView(placeholder)
    }

    private fun assertViewReleased(factory: VModalFactory, view: View) {
        listOf("dialogs", "contentContainers", "dismissHandlers").forEach { fieldName ->
            assertFalse("$fieldName retained the destroyed view", stateMap(factory, fieldName).containsKey(view))
        }
    }

    private fun stateMap(factory: VModalFactory, fieldName: String): Map<*, *> {
        val field = VModalFactory::class.java.getDeclaredField(fieldName)
        field.isAccessible = true
        return field.get(factory) as Map<*, *>
    }

    @Suppress("UNCHECKED_CAST")
    private fun <K, V> mutableStateMap(factory: VModalFactory, fieldName: String): MutableMap<K, V> =
        stateMap(factory, fieldName) as MutableMap<K, V>

    private class SynchronousDismissDialog(context: Context) : Dialog(context) {
        private var dismissListener: DialogInterface.OnDismissListener? = null
        private var showing = true
        var listenerWasClearedBeforeDismiss = false
            private set

        override fun setOnDismissListener(listener: DialogInterface.OnDismissListener?) {
            dismissListener = listener
        }

        override fun isShowing(): Boolean = showing

        override fun dismiss() {
            listenerWasClearedBeforeDismiss = dismissListener == null
            showing = false
            dismissListener?.onDismiss(this)
        }
    }
}
