package com.vuenative.core

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
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
import org.robolectric.shadows.ShadowMediaMetadataRetriever

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class CameraModuleTest {
    private lateinit var context: Context
    private lateinit var bridge: NativeBridge
    private lateinit var module: CameraModule
    private lateinit var activity: Activity

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        bridge = NativeBridge(context)
        module = CameraModule()
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        CameraModule.setActivity(activity)
        ShadowMediaMetadataRetriever.reset()
        resetFileProviderPathStrategyCache()
    }

    /**
     * `androidx.core.content.FileProvider` resolves its cache-dir root the
     * first time [androidx.core.content.FileProvider.getUriForFile] is called
     * for a given authority, then caches that [androidx.core.content.FileProvider]
     * `PathStrategy` forever in a static `sCache` map keyed only by authority
     * string. That is a correct, harmless optimization on a real device (a
     * process's cacheDir never moves), but Robolectric allocates a brand new,
     * uniquely named temp `cacheDir` for every single test method — so once
     * one test resolves and caches a `PathStrategy`, every later test's actual
     * cacheDir path falls outside that stale cached root, and
     * `getUriForFile()` throws "Failed to find configured root...". Clearing
     * the cache before each test is a pure test-isolation fix; it does not
     * touch CameraModule's production code path.
     */
    private fun resetFileProviderPathStrategyCache() {
        val field = androidx.core.content.FileProvider::class.java.getDeclaredField("sCache")
        field.isAccessible = true
        (field.get(null) as MutableMap<*, *>).clear()
    }

    @After
    fun tearDown() {
        // Clears the static Activity reference and settles any in-flight
        // capture so pending callbacks never leak into the next test.
        CameraModule.clearActivity(activity)
    }

    /** Read the companion's private in-flight output file via reflection (mirrors the pending-state files other companion-backed modules expose only internally). */
    private fun pendingOutputFile(): File? {
        val field = CameraModule::class.java.getDeclaredField("pendingOutputFile")
        field.isAccessible = true
        return field.get(null) as File?
    }

    private fun writeJpeg(file: File, width: Int, height: Int) {
        file.parentFile?.mkdirs()
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        file.outputStream().use { out -> bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out) }
        bitmap.recycle()
    }

    // -------------------------------------------------------------------------
    // Module basics
    // -------------------------------------------------------------------------

    @Test
    fun moduleIsNamedCamera() {
        assertEquals("Camera", module.moduleName)
    }

    @Test
    fun unknownMethodReturnsError() {
        var error: String? = null
        module.invoke("bogus", emptyList(), bridge) { _, err -> error = err }
        assertNotNull(error)
        assertTrue(error!!.contains("bogus"))
    }

    @Test
    fun stopQRScanIsANoOp() {
        var result: Any? = "sentinel"
        var error: String? = "sentinel"
        module.invoke("stopQRScan", emptyList(), bridge) { value, err ->
            result = value
            error = err
        }
        assertNull(result)
        assertNull(error)
    }

    @Test
    fun scanQRCodeReturnsAnActionableAndroidGapError() {
        var error: String? = null
        module.invoke("scanQRCode", emptyList(), bridge) { _, err -> error = err }
        assertNotNull(error)
        assertTrue(error!!.contains("not yet supported on Android"))
        assertTrue(error!!.contains("iOS"))
    }

    // -------------------------------------------------------------------------
    // launchCamera
    // -------------------------------------------------------------------------

    @Test
    fun launchCameraRequiresActivityHost() {
        CameraModule.clearActivity(activity)

        var result: Any? = "sentinel"
        var error: String? = null
        module.invoke("launchCamera", emptyList(), bridge) { value, err ->
            result = value
            error = err
        }

        assertNull(result)
        assertNotNull(error)
        assertTrue(error!!.contains("Activity"))
    }

    @Test
    fun launchCameraStartsImageCaptureIntentWithFileProviderOutput() {
        var settled = false
        module.invoke("launchCamera", emptyList(), bridge) { _, _ -> settled = true }

        val started = shadowOf(activity).nextStartedActivityForResult
        assertNotNull("launchCamera should start an activity for result", started)
        assertEquals(MediaStore.ACTION_IMAGE_CAPTURE, started.intent.action)
        val output = started.intent.getParcelableExtra<Uri>(MediaStore.EXTRA_OUTPUT)
        assertNotNull("EXTRA_OUTPUT should carry a FileProvider content Uri", output)
        assertEquals("content", output!!.scheme)
        assertTrue(
            (started.intent.flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION) != 0,
        )
        // The callback stays pending until onActivityResult arrives.
        assertFalse("Callback must not settle before a result arrives", settled)
    }

    @Test
    fun launchCameraCancellationResolvesDidCancel() {
        var result: Any? = null
        var error: String? = "not_called"
        module.invoke("launchCamera", emptyList(), bridge) { value, err ->
            result = value
            error = err
        }

        CameraModule.onActivityResult(9_301, Activity.RESULT_CANCELED, null)

        assertNull(error)
        assertEquals(mapOf("didCancel" to true), result)
    }

    @Test
    fun launchCameraSuccessResolvesUriWidthHeightAndType() {
        var result: Any? = null
        var error: String? = "not_called"
        module.invoke("launchCamera", emptyList(), bridge) { value, err ->
            result = value
            error = err
        }

        // Simulate the external camera app writing the captured photo into the
        // file this module pre-allocated and handed it via EXTRA_OUTPUT.
        val file = pendingOutputFile()
        assertNotNull("launchCamera should have pre-allocated an output file", file)
        writeJpeg(file!!, 48, 32)

        CameraModule.onActivityResult(9_301, Activity.RESULT_OK, null)

        assertNull(error)
        val photo = result as Map<*, *>
        assertEquals("image/jpeg", photo["type"])
        assertEquals(48, photo["width"])
        assertEquals(32, photo["height"])
        assertTrue((photo["uri"] as String).startsWith("file://"))
    }

    @Test
    fun launchCameraWithNoCapturedFileResolvesDidCancel() {
        // A RESULT_OK with no bytes ever written (e.g. the camera app crashed
        // without producing output) must not be reported as a successful photo.
        var result: Any? = null
        module.invoke("launchCamera", emptyList(), bridge) { value, _ -> result = value }

        CameraModule.onActivityResult(9_301, Activity.RESULT_OK, null)

        assertEquals(mapOf("didCancel" to true), result)
    }

    // -------------------------------------------------------------------------
    // launchImageLibrary
    // -------------------------------------------------------------------------

    @Test
    fun launchImageLibraryRequiresActivityHost() {
        CameraModule.clearActivity(activity)

        var error: String? = null
        module.invoke("launchImageLibrary", emptyList(), bridge) { _, err -> error = err }

        assertNotNull(error)
        assertTrue(error!!.contains("Activity"))
    }

    @Test
    fun launchImageLibraryStartsSystemPicker() {
        var settled = false
        module.invoke("launchImageLibrary", emptyList(), bridge) { _, _ -> settled = true }

        val started = shadowOf(activity).nextStartedActivityForResult
        assertNotNull("launchImageLibrary should start an activity for result", started)
        // sdk 34 (Tiramisu+) uses the dedicated Photo Picker, same as ImagePickerModule.
        assertEquals(MediaStore.ACTION_PICK_IMAGES, started.intent.action)
        assertFalse(settled)
    }

    @Test
    fun launchImageLibraryCancellationResolvesDidCancel() {
        var result: Any? = null
        module.invoke("launchImageLibrary", emptyList(), bridge) { value, _ -> result = value }

        CameraModule.onActivityResult(9_302, Activity.RESULT_CANCELED, null)

        assertEquals(mapOf("didCancel" to true), result)
    }

    @Test
    fun launchImageLibrarySuccessResolvesUriWidthHeightAndType() {
        val file = File(context.cacheDir, "picked-image.jpg")
        writeJpeg(file, 20, 10)
        val uri = Uri.fromFile(file)

        var result: Any? = null
        var error: String? = "not_called"
        module.invoke("launchImageLibrary", emptyList(), bridge) { value, err ->
            result = value
            error = err
        }

        CameraModule.onActivityResult(9_302, Activity.RESULT_OK, Intent().apply { data = uri })

        assertNull(error)
        val photo = result as Map<*, *>
        assertEquals(uri.toString(), photo["uri"])
        assertEquals(20, photo["width"])
        assertEquals(10, photo["height"])
        assertNotNull(photo["type"])
    }

    // -------------------------------------------------------------------------
    // captureVideo
    // -------------------------------------------------------------------------

    @Test
    fun captureVideoRequiresActivityHost() {
        CameraModule.clearActivity(activity)

        var error: String? = null
        module.invoke("captureVideo", emptyList(), bridge) { _, err -> error = err }

        assertNotNull(error)
        assertTrue(error!!.contains("Activity"))
    }

    @Test
    fun captureVideoStartsVideoCaptureIntentWithOptions() {
        module.invoke(
            "captureVideo",
            listOf(mapOf("quality" to "low", "maxDuration" to 30, "frontCamera" to true)),
            bridge,
        ) { _, _ -> }

        val started = shadowOf(activity).nextStartedActivityForResult
        assertNotNull(started)
        assertEquals(MediaStore.ACTION_VIDEO_CAPTURE, started.intent.action)
        assertEquals(0, started.intent.getIntExtra(MediaStore.EXTRA_VIDEO_QUALITY, -1))
        assertEquals(30, started.intent.getIntExtra(MediaStore.EXTRA_DURATION_LIMIT, -1))
        val output = started.intent.getParcelableExtra<Uri>(MediaStore.EXTRA_OUTPUT)
        assertNotNull("EXTRA_OUTPUT should carry a FileProvider content Uri", output)
    }

    @Test
    fun captureVideoDefaultsToHighQualityWhenUnspecified() {
        module.invoke("captureVideo", emptyList(), bridge) { _, _ -> }

        val started = shadowOf(activity).nextStartedActivityForResult
        assertEquals(1, started.intent.getIntExtra(MediaStore.EXTRA_VIDEO_QUALITY, -1))
    }

    @Test
    fun captureVideoCancellationResolvesDidCancel() {
        var result: Any? = null
        module.invoke("captureVideo", emptyList(), bridge) { value, _ -> result = value }

        CameraModule.onActivityResult(9_303, Activity.RESULT_CANCELED, null)

        assertEquals(mapOf("didCancel" to true), result)
    }

    @Test
    fun captureVideoSuccessResolvesUriDurationAndType() {
        var result: Any? = null
        var error: String? = "not_called"
        module.invoke("captureVideo", emptyList(), bridge) { value, err ->
            result = value
            error = err
        }

        val file = pendingOutputFile()
        assertNotNull("captureVideo should have pre-allocated an output file", file)
        file!!.parentFile?.mkdirs()
        file.writeBytes(byteArrayOf(1, 2, 3, 4))
        // Robolectric's MediaMetadataRetriever shadow needs metadata configured
        // explicitly — it has no real decoder to inspect the (fake) file bytes.
        ShadowMediaMetadataRetriever.addMetadata(
            file.absolutePath,
            MediaMetadataRetriever.METADATA_KEY_DURATION,
            "5000",
        )

        CameraModule.onActivityResult(9_303, Activity.RESULT_OK, null)

        assertNull(error)
        val video = result as Map<*, *>
        assertEquals("video/mp4", video["type"])
        assertEquals(5.0, video["duration"] as Double, 0.001)
        assertTrue((video["uri"] as String).startsWith("file://"))
    }

    @Test
    fun captureVideoWithNoCapturedFileResolvesDidCancel() {
        var result: Any? = null
        module.invoke("captureVideo", emptyList(), bridge) { value, _ -> result = value }

        CameraModule.onActivityResult(9_303, Activity.RESULT_OK, null)

        assertEquals(mapOf("didCancel" to true), result)
    }

    // -------------------------------------------------------------------------
    // Superseding / teardown semantics
    // -------------------------------------------------------------------------

    @Test
    fun newCaptureSupersedesAndCancelsThePreviousOne() {
        var firstResult: Any? = "pending"
        module.invoke("launchCamera", emptyList(), bridge) { value, _ -> firstResult = value }

        var secondSettled = false
        module.invoke("launchImageLibrary", emptyList(), bridge) { _, _ -> secondSettled = true }

        assertEquals(
            "The superseded capture must resolve as cancelled rather than hang",
            mapOf("didCancel" to true),
            firstResult,
        )
        assertFalse("The new pending pick must still be waiting on its own result", secondSettled)
    }

    @Test
    fun clearActivityFailsAnInFlightCaptureAndDeletesItsTempFile() {
        var result: Any? = "pending"
        var error: String? = null
        module.invoke("launchCamera", emptyList(), bridge) { value, err ->
            result = value
            error = err
        }
        val file = pendingOutputFile()
        assertNotNull(file)
        file!!.parentFile?.mkdirs()
        file.writeBytes(byteArrayOf(9))
        assertTrue(file.exists())

        CameraModule.clearActivity(activity)

        assertNull(result)
        assertNotNull(error)
        assertTrue(error!!.contains("destroyed"))
        assertFalse("The abandoned temp file must be cleaned up", file.exists())
    }

    @Test
    fun fileProviderAuthorityIsScopedToTheHostPackage() {
        val authority = CameraModule.fileProviderAuthority(context)
        assertTrue(authority.startsWith(context.packageName))
        assertTrue(authority.endsWith(".vuenative.fileprovider"))
    }
}
