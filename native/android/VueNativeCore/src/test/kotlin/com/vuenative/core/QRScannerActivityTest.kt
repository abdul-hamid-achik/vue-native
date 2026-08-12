package com.vuenative.core

import android.Manifest
import android.app.Application
import android.content.pm.PackageManager
import android.graphics.Rect
import androidx.test.core.app.ApplicationProvider
import com.google.mlkit.vision.barcode.common.Barcode
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Only what's testable on the JVM: the pure format/bounds mapping (see
 * [QRScannerActivity.contractType] / [QRScannerActivity.normalizedBounds])
 * and the permission-request/denial flow. Real ML Kit frame analysis needs a
 * physical camera and is not exercised here.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class QRScannerActivityTest {

    @Before
    fun setUp() {
        val app = ApplicationProvider.getApplicationContext<Application>()
        shadowOf(app).denyPermissions(Manifest.permission.CAMERA)
    }

    // -------------------------------------------------------------------------
    // contractType() — mirrors AVMetadataObject.ObjectType.rawValue on iOS so
    // the `camera:qrDetected` payload's `type` field is identical cross-platform.
    // -------------------------------------------------------------------------

    @Test
    fun contractTypeMirrorsIosRawValuesForEverySupportedFormat() {
        assertEquals("org.iso.QRCode", QRScannerActivity.contractType(Barcode.FORMAT_QR_CODE))
        assertEquals("org.gs1.EAN-8", QRScannerActivity.contractType(Barcode.FORMAT_EAN_8))
        assertEquals("org.gs1.EAN-13", QRScannerActivity.contractType(Barcode.FORMAT_EAN_13))
        assertEquals("org.iso.PDF417", QRScannerActivity.contractType(Barcode.FORMAT_PDF417))
        assertEquals("org.gs1.Code128", QRScannerActivity.contractType(Barcode.FORMAT_CODE_128))
    }

    @Test
    fun contractTypeFallsBackToUnknownForAnUnsupportedFormat() {
        assertEquals("unknown", QRScannerActivity.contractType(Barcode.FORMAT_UNKNOWN))
    }

    @Test
    fun supportedFormatsMatchTheIosMetadataObjectTypesList() {
        // [.qr, .ean8, .ean13, .pdf417, .code128] on iOS (CameraModule.swift).
        assertEquals(5, QRScannerActivity.SUPPORTED_FORMATS.size)
        assertTrue(QRScannerActivity.SUPPORTED_FORMATS.contains(Barcode.FORMAT_QR_CODE))
        assertTrue(QRScannerActivity.SUPPORTED_FORMATS.contains(Barcode.FORMAT_EAN_8))
        assertTrue(QRScannerActivity.SUPPORTED_FORMATS.contains(Barcode.FORMAT_EAN_13))
        assertTrue(QRScannerActivity.SUPPORTED_FORMATS.contains(Barcode.FORMAT_PDF417))
        assertTrue(QRScannerActivity.SUPPORTED_FORMATS.contains(Barcode.FORMAT_CODE_128))
    }

    // -------------------------------------------------------------------------
    // normalizedBounds() — pixel bounding box -> 0-1 normalized QRCodeResult.bounds
    // -------------------------------------------------------------------------

    @Test
    fun normalizedBoundsDividesByImageDimensions() {
        val box = Rect(10, 20, 110, 220) // left, top, right, bottom
        val bounds = QRScannerActivity.normalizedBounds(box, 200, 400)

        assertEquals(0.05, bounds["x"]!!, 0.0001)
        assertEquals(0.05, bounds["y"]!!, 0.0001)
        assertEquals(0.5, bounds["width"]!!, 0.0001)
        assertEquals(0.5, bounds["height"]!!, 0.0001)
    }

    @Test
    fun normalizedBoundsIsZeroedWhenTheBoxIsMissing() {
        val bounds = QRScannerActivity.normalizedBounds(null, 200, 400)
        assertEquals(0.0, bounds["x"])
        assertEquals(0.0, bounds["y"])
        assertEquals(0.0, bounds["width"])
        assertEquals(0.0, bounds["height"])
    }

    @Test
    fun normalizedBoundsIsZeroedRatherThanDividingByZero() {
        val bounds = QRScannerActivity.normalizedBounds(Rect(0, 0, 10, 10), 0, 0)
        assertEquals(0.0, bounds["width"])
        assertEquals(0.0, bounds["height"])
    }

    // -------------------------------------------------------------------------
    // Camera permission — requested on create, scanner closes if denied.
    // -------------------------------------------------------------------------

    @Test
    fun requestsCameraPermissionWhenNotYetGranted() {
        val activity = Robolectric.buildActivity(QRScannerActivity::class.java).create().get()

        val requested = shadowOf(activity).lastRequestedPermission
        assertNotNull("QRScannerActivity should request CAMERA when not already granted", requested)
        assertArrayEquals(arrayOf(Manifest.permission.CAMERA), requested.requestedPermissions)
        assertTrue("Activity must not finish while the permission prompt is pending", !activity.isFinishing)
    }

    @Test
    fun finishesWhenCameraPermissionIsDenied() {
        val activity = Robolectric.buildActivity(QRScannerActivity::class.java).create().get()
        val requested = shadowOf(activity).lastRequestedPermission

        activity.onRequestPermissionsResult(
            requested.requestCode,
            requested.requestedPermissions,
            intArrayOf(PackageManager.PERMISSION_DENIED),
        )

        assertTrue("Denied camera permission should close the scanner", activity.isFinishing)
    }

    // -------------------------------------------------------------------------
    // CameraModule interplay — stopQRScan() closes the active scanner
    // -------------------------------------------------------------------------

    @Test
    fun stopQRScanFinishesTheActiveScannerActivity() {
        val controller = Robolectric.buildActivity(QRScannerActivity::class.java).create()
        val activity = controller.get()
        val bridge = NativeBridge(activity)
        val module = CameraModule()

        var settled = false
        module.invoke("stopQRScan", emptyList(), bridge) { _, _ -> settled = true }
        // onQrScannerOpened() was called from QRScannerActivity.onCreate() above,
        // so this stopQRScan() call must finish the activity it registered.
        assertTrue(settled)
        assertTrue("stopQRScan should finish the running scanner activity", activity.isFinishing)
        controller.destroy()
    }

    @Test
    fun onDestroyClearsTheActiveScannerReferenceSoStopQRScanIsThenANoOp() {
        val controller = Robolectric.buildActivity(QRScannerActivity::class.java).create()
        controller.destroy()

        val bridge = NativeBridge(ApplicationProvider.getApplicationContext())
        val module = CameraModule()
        var result: Any? = "sentinel"
        var error: String? = "sentinel"
        module.invoke("stopQRScan", emptyList(), bridge) { value, err ->
            result = value
            error = err
        }

        assertEquals(null, result)
        assertEquals(null, error)
    }
}
