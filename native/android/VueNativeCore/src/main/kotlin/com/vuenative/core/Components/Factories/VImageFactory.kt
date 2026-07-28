package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import androidx.core.content.ContextCompat
import coil.load
import coil.request.CachePolicy
import org.json.JSONObject

class VImageFactory : NativeComponentFactory {
    private val loadHandlers = mutableMapOf<ImageView, (Any?) -> Unit>()
    private val errorHandlers = mutableMapOf<ImageView, (Any?) -> Unit>()

    override fun createView(context: Context): View {
        return ImageView(context).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val iv = view as? ImageView ?: return
        when (key) {
            "source" -> {
                val uri: String?
                val asset: String?
                when (value) {
                    is Map<*, *> -> {
                        uri = value["uri"]?.toString()
                        asset = value["asset"]?.toString()
                    }
                    is JSONObject -> {
                        uri = value.optString("uri").takeIf { it.isNotEmpty() }
                        asset = value.optString("asset").takeIf { it.isNotEmpty() }
                    }
                    else -> {
                        uri = null
                        asset = null
                    }
                }

                // A bundled drawable asset takes precedence over a remote URI.
                if (!asset.isNullOrEmpty()) {
                    loadAsset(iv, asset)
                    return
                }
                if (uri.isNullOrEmpty()) {
                    iv.setImageDrawable(null)
                    return
                }
                iv.load(uri) {
                    memoryCachePolicy(CachePolicy.ENABLED)
                    diskCachePolicy(CachePolicy.ENABLED)
                    listener(
                        onSuccess = { _, _ -> loadHandlers[iv]?.invoke(null) },
                        onError = { _, err -> errorHandlers[iv]?.invoke(mapOf("message" to (err.throwable.message ?: "Load failed"))) }
                    )
                }
            }
            "resizeMode" -> {
                iv.scaleType = when (value) {
                    "cover" -> ImageView.ScaleType.CENTER_CROP
                    "contain" -> ImageView.ScaleType.FIT_CENTER
                    "stretch" -> ImageView.ScaleType.FIT_XY
                    "center" -> ImageView.ScaleType.CENTER
                    else -> ImageView.ScaleType.CENTER_CROP
                }
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    /**
     * Load a bundled `res/drawable` resource by name. Fires `load` on success
     * and `error` when the resource is missing or cannot be resolved.
     */
    private fun loadAsset(iv: ImageView, asset: String) {
        val context = iv.context
        val resId = context.resources.getIdentifier(asset, "drawable", context.packageName)
        if (resId == 0) {
            iv.setImageDrawable(null)
            errorHandlers[iv]?.invoke(mapOf("message" to "Asset not found: $asset"))
            return
        }
        val drawable = ContextCompat.getDrawable(context, resId)
        if (drawable == null) {
            iv.setImageDrawable(null)
            errorHandlers[iv]?.invoke(mapOf("message" to "Failed to load asset: $asset"))
            return
        }
        iv.setImageDrawable(drawable)
        loadHandlers[iv]?.invoke(null)
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val iv = view as? ImageView ?: return
        when (event) {
            "load" -> loadHandlers[iv] = handler
            "error" -> errorHandlers[iv] = handler
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val iv = view as? ImageView ?: return
        when (event) {
            "load" -> loadHandlers.remove(iv)
            "error" -> errorHandlers.remove(iv)
        }
    }

    override fun destroyView(view: View) {
        val iv = view as? ImageView ?: return
        loadHandlers.remove(iv)
        errorHandlers.remove(iv)
        // Replacing the request with an empty source cancels any in-flight Coil load.
        iv.load(null)
        iv.setImageDrawable(null)
    }
}
