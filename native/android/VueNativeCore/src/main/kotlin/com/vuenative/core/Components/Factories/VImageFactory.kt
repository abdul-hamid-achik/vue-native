package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
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
                val uri = when (value) {
                    is Map<*, *> -> value["uri"]?.toString()
                    is JSONObject -> value.optString("uri")
                    else -> null
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
}
