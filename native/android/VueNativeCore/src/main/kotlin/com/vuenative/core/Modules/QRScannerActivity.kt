package com.vuenative.core

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Rect
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Full-screen QR/barcode scanner backing `Camera.scanQRCode`.
 *
 * Shows a live [PreviewView] and runs every frame through an ML Kit
 * [BarcodeScanner] (bundled model — see build.gradle.kts, no Google Play
 * Services dependency). Every detected code is forwarded to
 * [CameraModule.dispatchQrDetected], which relays it to JS as the
 * `camera:qrDetected` global event — mirroring iOS's `QRScanDelegate`
 * (`CameraModule.swift`), which likewise fires on *every* frame containing a
 * code rather than stopping after the first one; the caller decides when to
 * stop via `stopQRScan()` (see `useCamera.ts`'s `onQRCodeDetected` doc note:
 * "can fire multiple times if scanning continues").
 *
 * The user can back out at any time (system back button or the Close
 * button); [onDestroy] unbinds the camera and notifies [CameraModule] so a
 * subsequent `stopQRScan()` call is a harmless no-op.
 */
class QRScannerActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "VueNative-QRScanner"
        internal const val REQUEST_CODE_CAMERA_PERMISSION = 9_310

        /**
         * Formats registered with the ML Kit scanner — mirrors the
         * `AVCaptureMetadataOutput.metadataObjectTypes` iOS registers in
         * `CameraModule.scanQRCode` (`[.qr, .ean8, .ean13, .pdf417, .code128]`).
         */
        internal val SUPPORTED_FORMATS = intArrayOf(
            Barcode.FORMAT_QR_CODE,
            Barcode.FORMAT_EAN_8,
            Barcode.FORMAT_EAN_13,
            Barcode.FORMAT_PDF417,
            Barcode.FORMAT_CODE_128,
        )

        /**
         * Maps an ML Kit `Barcode.FORMAT_*` constant to the same dotted
         * identifier string `AVMetadataObject.ObjectType.rawValue` produces on
         * iOS, so the `type` field of the `camera:qrDetected` payload is
         * identical across platforms.
         */
        internal fun contractType(format: Int): String = when (format) {
            Barcode.FORMAT_QR_CODE -> "org.iso.QRCode"
            Barcode.FORMAT_EAN_8 -> "org.gs1.EAN-8"
            Barcode.FORMAT_EAN_13 -> "org.gs1.EAN-13"
            Barcode.FORMAT_PDF417 -> "org.iso.PDF417"
            Barcode.FORMAT_CODE_128 -> "org.gs1.Code128"
            else -> "unknown"
        }

        /**
         * Normalizes a detected barcode's bounding box (pixels, in the
         * analyzed frame's coordinate space) to the 0-1 range documented by
         * `QRCodeResult.bounds` in `useCamera.ts`. Returns a zeroed box for a
         * missing box or degenerate (zero-sized) frame instead of dividing by
         * zero.
         */
        internal fun normalizedBounds(box: Rect?, imageWidth: Int, imageHeight: Int): Map<String, Double> {
            if (box == null || imageWidth <= 0 || imageHeight <= 0) {
                return mapOf("x" to 0.0, "y" to 0.0, "width" to 0.0, "height" to 0.0)
            }
            return mapOf(
                "x" to box.left.toDouble() / imageWidth,
                "y" to box.top.toDouble() / imageHeight,
                "width" to box.width().toDouble() / imageWidth,
                "height" to box.height().toDouble() / imageHeight,
            )
        }
    }

    private lateinit var previewView: PreviewView
    private lateinit var cameraExecutor: ExecutorService
    private var cameraProvider: ProcessCameraProvider? = null
    private var scanner: BarcodeScanner? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Guarantees an AppCompat theme even if a host app's manifest merger
        // ever drops/overrides this activity's declared theme — AppCompatActivity
        // throws on create() without one.
        setTheme(androidx.appcompat.R.style.Theme_AppCompat_NoActionBar)
        super.onCreate(savedInstanceState)
        CameraModule.onQrScannerOpened(this)
        cameraExecutor = Executors.newSingleThreadExecutor()
        setContentView(buildLayout())

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            startScanning()
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), REQUEST_CODE_CAMERA_PERMISSION)
        }
    }

    private fun buildLayout(): ViewGroup {
        previewView = PreviewView(this)
        val root = FrameLayout(this).apply {
            addView(previewView, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        }

        val dp = resources.displayMetrics.density
        val hint = TextView(this).apply {
            text = "Point the camera at a QR code"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#99000000"))
            setPadding((12 * dp).toInt(), (6 * dp).toInt(), (12 * dp).toInt(), (6 * dp).toInt())
        }
        root.addView(
            hint,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.CENTER_HORIZONTAL,
            ).apply { topMargin = (24 * dp).toInt() },
        )

        val close = Button(this).apply {
            text = "Close"
            setOnClickListener { finish() }
        }
        root.addView(
            close,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.START,
            ).apply {
                topMargin = (16 * dp).toInt()
                leftMargin = (16 * dp).toInt()
            },
        )

        return root
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CODE_CAMERA_PERMISSION) return
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startScanning()
        } else {
            Log.w(TAG, "Camera permission denied — closing QR scanner")
            Toast.makeText(this, "Camera permission is required to scan QR codes", Toast.LENGTH_LONG).show()
            finish()
        }
    }

    private fun startScanning() {
        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(SUPPORTED_FORMATS.first(), *SUPPORTED_FORMATS.drop(1).toIntArray())
            .build()
        scanner = BarcodeScanning.getClient(options)

        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener(
            {
                val provider = providerFuture.get()
                cameraProvider = provider

                val preview = Preview.Builder().build().also {
                    it.surfaceProvider = previewView.surfaceProvider
                }
                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .also { it.setAnalyzer(cameraExecutor, ::analyzeFrame) }

                try {
                    provider.unbindAll()
                    provider.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to bind QR scanner camera: ${e.message}")
                    Toast.makeText(this, "Unable to start the camera", Toast.LENGTH_LONG).show()
                    finish()
                }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    private fun analyzeFrame(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        val currentScanner = scanner
        if (mediaImage == null || currentScanner == null) {
            imageProxy.close()
            return
        }
        val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
        currentScanner.process(image)
            .addOnSuccessListener { barcodes -> handleDetectedBarcodes(barcodes, image.width, image.height) }
            .addOnFailureListener { e -> Log.w(TAG, "Barcode analysis failed: ${e.message}") }
            .addOnCompleteListener { imageProxy.close() }
    }

    private fun handleDetectedBarcodes(barcodes: List<Barcode>, imageWidth: Int, imageHeight: Int) {
        // Every detected code in every frame is dispatched — no dedup, no
        // auto-close — matching iOS's QRScanDelegate, which fires its
        // metadata-output delegate callback (and dispatches the event) on
        // every frame a code is visible in until stopQRScan() is called.
        barcodes.forEach { barcode ->
            val data = barcode.rawValue ?: barcode.displayValue ?: return@forEach
            if (data.isEmpty()) return@forEach
            CameraModule.dispatchQrDetected(
                mapOf(
                    "data" to data,
                    "type" to contractType(barcode.format),
                    "bounds" to normalizedBounds(barcode.boundingBox, imageWidth, imageHeight),
                ),
            )
        }
    }

    override fun onDestroy() {
        cameraProvider?.unbindAll()
        scanner?.close()
        cameraExecutor.shutdown()
        CameraModule.onQrScannerClosed(this)
        super.onDestroy()
    }
}
