package com.vuenative.core

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.provider.MediaStore
import androidx.test.core.app.ApplicationProvider
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ImagePickerModuleTest {
    private lateinit var context: Context
    private lateinit var bridge: NativeBridge
    private lateinit var module: ImagePickerModule
    private lateinit var activity: Activity

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        bridge = NativeBridge(context)
        module = ImagePickerModule()
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        ImagePickerModule.setActivity(activity)
    }

    @After
    fun tearDown() {
        // Clears the static Activity reference and settles any in-flight pick so
        // pending callbacks never leak into the next test.
        ImagePickerModule.clearActivity(activity)
    }

    @Test
    fun moduleIsNamedImagePicker() {
        assertEquals("ImagePicker", module.moduleName)
    }

    @Test
    fun unknownMethodReturnsError() {
        var error: String? = null
        module.invoke("bogus", emptyList(), bridge) { _, err -> error = err }
        assertNotNull(error)
        assertTrue(error!!.contains("bogus"))
    }

    @Test
    fun pickImageRequiresActivityHost() {
        ImagePickerModule.clearActivity(activity)

        var result: Any? = "sentinel"
        var error: String? = null
        module.invoke("pickImage", emptyList(), bridge) { value, err ->
            result = value
            error = err
        }

        assertNull(result)
        assertNotNull(error)
        assertTrue(error!!.contains("Activity"))
    }

    @Test
    fun pickImageLaunchesSystemPhotoPicker() {
        var settled = false
        module.invoke("pickImage", emptyList(), bridge) { _, _ -> settled = true }

        val started = shadowOf(activity).nextStartedActivityForResult
        assertNotNull("pickImage should start an activity for result", started)
        assertEquals(ImagePickerModule.REQUEST_CODE, started.requestCode)
        // sdk 34 (Tiramisu+) uses the dedicated Photo Picker.
        assertEquals(MediaStore.ACTION_PICK_IMAGES, started.intent.action)
        // The callback stays pending until onActivityResult arrives.
        assertFalse("Callback must not settle before a result arrives", settled)
    }

    @Test
    fun pickImageCancellationResolvesNull() {
        var result: Any? = "sentinel"
        var error: String? = "not_called"
        module.invoke("pickImage", emptyList(), bridge) { value, err ->
            result = value
            error = err
        }

        ImagePickerModule.onActivityResult(
            ImagePickerModule.REQUEST_CODE,
            Activity.RESULT_CANCELED,
            null,
        )

        assertNull("Cancellation should resolve to null", result)
        assertNull("Cancellation should not error", error)
    }

    @Test
    fun pickImageResultResolvesUriAndDimensions() {
        val uri = writeBitmapUri(12, 34)

        var result: Any? = null
        var error: String? = "not_called"
        module.invoke("pickImage", emptyList(), bridge) { value, err ->
            result = value
            error = err
        }

        val resultIntent = Intent().apply { data = uri }
        ImagePickerModule.onActivityResult(
            ImagePickerModule.REQUEST_CODE,
            Activity.RESULT_OK,
            resultIntent,
        )

        assertNull(error)
        val photo = result as Map<*, *>
        assertEquals(uri.toString(), photo["uri"])
        assertEquals(12, photo["width"])
        assertEquals(34, photo["height"])
    }

    @Test
    fun readImageDimensionsDecodesBoundsWithoutAllocating() {
        val uri = writeBitmapUri(20, 10)
        val dims = ImagePickerModule.readImageDimensions(context.contentResolver, uri)
        assertNotNull(dims)
        assertEquals(20, dims!!.first)
        assertEquals(10, dims.second)
    }

    @Test
    fun buildPickIntentUsesPhotoPickerOnApi33Plus() {
        // This suite runs at sdk 34 (Tiramisu+).
        assertEquals(MediaStore.ACTION_PICK_IMAGES, ImagePickerModule.buildPickIntent().action)
    }

    /** Write a real PNG of the given size to the cache dir and return its file URI. */
    private fun writeBitmapUri(width: Int, height: Int): Uri {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val file = File(context.cacheDir, "test-image-${width}x$height.png")
        file.outputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        bitmap.recycle()
        return Uri.fromFile(file)
    }
}
