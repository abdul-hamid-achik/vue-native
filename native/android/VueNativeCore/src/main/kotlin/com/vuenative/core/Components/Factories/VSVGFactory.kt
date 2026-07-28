package com.vuenative.core

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Picture
import android.graphics.PorterDuff
import android.graphics.RectF
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import com.caverock.androidsvg.SVG
import com.caverock.androidsvg.SVGParseException
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

/**
 * View that renders a vector [Picture] produced from an SVG document.
 *
 * The picture is drawn scaled to the view bounds so the SVG stays vector-crisp
 * at any size. When a tint color is set the picture is rasterized once and the
 * painted shape is recolored with a SRC_IN filter (a basic tint — see
 * [VSVGFactory] for the caveat).
 */
class SVGView(context: Context) : View(context) {

    private var picture: Picture? = null
    private var tintedBitmap: Bitmap? = null
    private var tintColor: Int? = null
    private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { isFilterBitmap = true }

    fun setPicture(newPicture: Picture?) {
        picture = newPicture
        rebuildTintedBitmap()
        invalidate()
    }

    fun setTintColor(color: Int?) {
        if (tintColor == color) return
        tintColor = color
        rebuildTintedBitmap()
        invalidate()
    }

    fun hasPicture(): Boolean = picture != null

    private fun rebuildTintedBitmap() {
        tintedBitmap?.recycle()
        tintedBitmap = null
        val pic = picture ?: return
        val color = tintColor ?: return
        val w = if (pic.width > 0) pic.width else 1
        val h = if (pic.height > 0) pic.height else 1
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawPicture(pic)
        // SRC_IN keeps the source color where the SVG already painted alpha,
        // effectively recoloring the opaque shape to the tint color.
        canvas.drawColor(color, PorterDuff.Mode.SRC_IN)
        tintedBitmap = bmp
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val tinted = tintedBitmap
        if (tinted != null) {
            canvas.drawBitmap(tinted, null, RectF(0f, 0f, width.toFloat(), height.toFloat()), bitmapPaint)
            return
        }
        val pic = picture ?: return
        val pw = pic.width.toFloat()
        val ph = pic.height.toFloat()
        if (pw <= 0f || ph <= 0f) {
            canvas.drawPicture(pic)
            return
        }
        canvas.save()
        canvas.scale(width / pw, height / ph)
        canvas.drawPicture(pic)
        canvas.restore()
    }
}

/**
 * VSVGFactory — factory for the VSVG component.
 *
 * Renders SVG documents natively via AndroidSVG. The `source` prop accepts
 * exactly one of:
 * - `svg`   — inline SVG markup (parsed synchronously).
 * - `asset` — a bundled SVG file under `assets/` (parsed synchronously).
 * - `uri`   — a remote SVG URL (downloaded asynchronously on a worker thread).
 *
 * Fires `load` after a successful parse + render and `error` on any parse or
 * load failure. `tintColor` applies a basic SRC_IN tint (see [SVGView]).
 */
class VSVGFactory : NativeComponentFactory {

    private val handlers = mutableMapOf<View, MutableMap<String, (Any?) -> Unit>>()

    // Per-view token used to discard stale async URI loads once a newer source
    // is set or the view is destroyed.
    private val requestTokens = mutableMapOf<View, Any>()

    private val uiHandler = Handler(Looper.getMainLooper())

    override fun createView(context: Context): View {
        return SVGView(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val svgView = view as? SVGView ?: return
        when (key) {
            "source" -> applySource(svgView, value)
            "tintColor" -> {
                // Null clears the tint; an invalid color keeps the previous one
                // (StyleEngine.parseColor parity with iOS/macOS fromHex).
                if (value == null) {
                    svgView.setTintColor(null)
                } else {
                    StyleEngine.parseColor(value)?.let { svgView.setTintColor(it) }
                }
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    private fun applySource(svgView: SVGView, value: Any?) {
        val svg: String?
        val asset: String?
        val uri: String?
        when (value) {
            is Map<*, *> -> {
                svg = value["svg"]?.toString()
                asset = value["asset"]?.toString()
                uri = value["uri"]?.toString()
            }
            is JSONObject -> {
                svg = value.optString("svg").takeIf { it.isNotEmpty() }
                asset = value.optString("asset").takeIf { it.isNotEmpty() }
                uri = value.optString("uri").takeIf { it.isNotEmpty() }
            }
            else -> {
                svg = null
                asset = null
                uri = null
            }
        }

        when {
            !svg.isNullOrEmpty() -> renderFromString(svgView, svg)
            !asset.isNullOrEmpty() -> renderFromAsset(svgView, asset)
            !uri.isNullOrEmpty() -> renderFromUri(svgView, uri)
            else -> {
                // Empty/unknown source: clear without firing events (VImage parity).
                invalidateToken(svgView)
                svgView.setPicture(null)
            }
        }
    }

    private fun renderFromString(svgView: SVGView, markup: String) {
        invalidateToken(svgView)
        try {
            renderParsed(svgView, SVG.getFromString(markup))
            fireEvent(svgView, "load", null)
        } catch (e: SVGParseException) {
            fail(svgView, e.message ?: "Invalid SVG markup")
        } catch (e: Exception) {
            fail(svgView, e.message ?: "SVG render failed")
        }
    }

    private fun renderFromAsset(svgView: SVGView, asset: String) {
        invalidateToken(svgView)
        try {
            renderParsed(svgView, SVG.getFromAsset(svgView.context.assets, asset))
            fireEvent(svgView, "load", null)
        } catch (e: Exception) {
            // Covers SVGParseException (bad markup) and IOException (missing asset).
            fail(svgView, e.message ?: "Failed to load SVG asset: $asset")
        }
    }

    private fun renderFromUri(svgView: SVGView, uri: String) {
        val token = Any()
        requestTokens[svgView] = token
        Thread {
            var parsed: SVG? = null
            var errorMessage: String? = null
            try {
                val connection = URL(uri).openConnection() as HttpURLConnection
                connection.connectTimeout = CONNECT_TIMEOUT_MS
                connection.readTimeout = READ_TIMEOUT_MS
                try {
                    connection.inputStream.use { parsed = SVG.getFromInputStream(it) }
                } finally {
                    connection.disconnect()
                }
            } catch (e: Exception) {
                errorMessage = e.message ?: "Failed to load SVG uri: $uri"
            }
            uiHandler.post {
                // Discard if a newer source replaced this one or the view is gone.
                if (requestTokens[svgView] !== token) return@post
                val svg = parsed
                if (svg != null) {
                    try {
                        renderParsed(svgView, svg)
                        fireEvent(svgView, "load", null)
                    } catch (e: Exception) {
                        fail(svgView, e.message ?: "SVG render failed")
                    }
                } else {
                    fail(svgView, errorMessage ?: "Failed to load SVG uri: $uri")
                }
            }
        }.start()
    }

    /** Render a parsed document to a [Picture] and hand it to the view. */
    private fun renderParsed(svgView: SVGView, svg: SVG) {
        val (w, h) = renderDimensions(svg)
        svgView.setPicture(svg.renderToPicture(w, h))
    }

    private fun fail(svgView: SVGView, message: String) {
        svgView.setPicture(null)
        fireEvent(svgView, "error", mapOf("message" to message))
    }

    /**
     * Choose a positive raster size for [SVG.renderToPicture]. Prefers the
     * document's intrinsic width/height, falls back to the viewBox aspect
     * ratio, and finally to a square default.
     */
    private fun renderDimensions(svg: SVG): Pair<Int, Int> {
        val dw = svg.documentWidth
        val dh = svg.documentHeight
        if (dw > 0f && dh > 0f) {
            return dw.toInt().coerceAtLeast(1) to dh.toInt().coerceAtLeast(1)
        }

        val aspect = svg.documentAspectRatio
        return when {
            aspect > 0f -> {
                val w = if (dw > 0f) dw.toInt() else DEFAULT_RENDER_SIZE
                w.coerceAtLeast(1) to (w / aspect).toInt().coerceAtLeast(1)
            }
            dw > 0f -> dw.toInt().coerceAtLeast(1) to dw.toInt().coerceAtLeast(1)
            dh > 0f -> dh.toInt().coerceAtLeast(1) to dh.toInt().coerceAtLeast(1)
            else -> DEFAULT_RENDER_SIZE to DEFAULT_RENDER_SIZE
        }
    }

    private fun invalidateToken(svgView: SVGView) {
        requestTokens.remove(svgView)
    }

    private fun fireEvent(view: View, event: String, payload: Any?) {
        handlers[view]?.get(event)?.invoke(payload)
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        handlers.getOrPut(view) { mutableMapOf() }[event] = handler
    }

    override fun removeEventListener(view: View, event: String) {
        handlers[view]?.remove(event)
    }

    override fun destroyView(view: View) {
        val svgView = view as? SVGView ?: return
        handlers.remove(svgView)
        // Invalidating the token turns any in-flight async load into a no-op.
        requestTokens.remove(svgView)
        svgView.setPicture(null)
    }

    private companion object {
        const val CONNECT_TIMEOUT_MS = 15_000
        const val READ_TIMEOUT_MS = 15_000
        const val DEFAULT_RENDER_SIZE = 512
    }
}
