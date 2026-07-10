package com.vuenative.core

import android.Manifest
import android.app.Application
import android.content.Context
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ModuleContractParityTest {
    private lateinit var context: Context
    private lateinit var bridge: NativeBridge

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        bridge = NativeBridge(context).also { it.hostContainer = FrameLayout(context) }
    }

    @Test
    fun clipboardSupportsRuntimeCopyAndPasteMethods() {
        val module = ClipboardModule().also { it.initialize(context, bridge) }

        var copyError: String? = "not_called"
        module.invoke("copy", listOf("Vue Native"), bridge) { _, error -> copyError = error }
        assertNull(copyError)

        var pasted: Any? = null
        var pasteError: String? = "not_called"
        module.invoke("paste", emptyList(), bridge) { result, error ->
            pasted = result
            pasteError = error
        }
        assertNull(pasteError)
        assertEquals("Vue Native", pasted)
    }

    @Test
    fun hapticsSupportsRuntimeNotificationFeedbackMethod() {
        val module = HapticsModule().also { it.initialize(context, bridge) }
        var resultError: String? = "not_called"

        module.invoke("notificationFeedback", listOf("success"), bridge) { _, error ->
            resultError = error
        }

        assertNull(resultError)
    }

    @Test
    fun keyboardGetHeightReturnsDocumentedObjectShapeWithoutActivity() {
        val module = KeyboardModule().also { it.initialize(context, bridge) }
        var result: Any? = null
        var resultError: String? = "not_called"

        module.invoke("getHeight", emptyList(), bridge) { value, error ->
            result = value
            resultError = error
        }

        assertNull(resultError)
        val metrics = result as Map<*, *>
        assertEquals(0, metrics["height"])
        assertEquals(false, metrics["isVisible"])
    }

    @Test
    fun geolocationRecognizesWatchAndClearWatchMethods() {
        shadowOf(context as Application).denyPermissions(Manifest.permission.ACCESS_FINE_LOCATION)
        val module = GeolocationModule().also { it.initialize(context, bridge) }

        var watchError: String? = null
        module.invoke("watchPosition", emptyList(), bridge) { _, error -> watchError = error }
        assertTrue(watchError?.contains("permission") == true)

        var clearError: String? = "not_called"
        module.invoke("clearWatch", listOf(1), bridge) { _, error -> clearError = error }
        assertNull(clearError)

        module.destroy()
    }

    @Test
    fun animationMeasuresRuntimeViewFrame() {
        val view = View(context).also { it.layout(0, 0, 120, 80) }
        bridge.nodeViews[42] = view
        val module = AnimationModule().also { it.initialize(context, bridge) }
        var result: Any? = null
        var resultError: String? = "not_called"

        module.invoke("measureView", listOf(42), bridge) { value, error ->
            result = value
            resultError = error
        }
        shadowOf(Looper.getMainLooper()).idle()

        assertNull(resultError)
        val frame = result as Map<*, *>
        assertEquals(120, frame["width"])
        assertEquals(80, frame["height"])
    }
}
