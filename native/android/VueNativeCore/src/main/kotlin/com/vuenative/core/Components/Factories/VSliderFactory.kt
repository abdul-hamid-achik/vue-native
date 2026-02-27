package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.SeekBar

class VSliderFactory : NativeComponentFactory {
    private val changeHandlers = mutableMapOf<SeekBar, (Any?) -> Unit>()

    override fun createView(context: Context): View {
        return SeekBar(context).apply {
            max = 100
            progress = 0
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val sb = view as? SeekBar ?: return
        when (key) {
            "value" -> {
                val v = StyleEngine.toFloat(value, 0f)
                val min = sb.min.toFloat()
                val max = sb.max.toFloat()
                sb.progress = ((v - min) / (max - min) * sb.max).toInt().coerceIn(0, sb.max)
            }
            "minimumValue" -> sb.min = StyleEngine.toFloat(value, 0f).toInt()
            "maximumValue" -> sb.max = StyleEngine.toFloat(value, 100f).toInt()
            "step" -> { /* SeekBar uses integer steps -- step is handled via progress scale */ }
            "minimumTrackTintColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                sb.progressTintList = android.content.res.ColorStateList.valueOf(color)
            }
            "maximumTrackTintColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                sb.progressBackgroundTintList = android.content.res.ColorStateList.valueOf(color)
            }
            "thumbTintColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                sb.thumbTintList = android.content.res.ColorStateList.valueOf(color)
            }
            "disabled" -> sb.isEnabled = value != true && value != "true"
            else -> StyleEngine.apply(key, value, view)
        }
    }

    private val throttles = mutableMapOf<SeekBar, EventThrottle>()

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val sb = view as? SeekBar ?: return
        when (event) {
            "change", "valueChange" -> {
                changeHandlers[sb] = handler
                val throttle = EventThrottle(intervalMs = 16L, handler = handler)
                throttles[sb] = throttle
                sb.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                    override fun onProgressChanged(s: SeekBar, progress: Int, fromUser: Boolean) {
                        if (fromUser) throttle.fire(mapOf("value" to progress.toFloat() / s.max.toFloat()))
                    }
                    override fun onStartTrackingTouch(s: SeekBar) {}
                    override fun onStopTrackingTouch(s: SeekBar) {
                        // Always deliver the final value immediately on release
                        throttle.cancel()
                        changeHandlers[s]?.invoke(mapOf("value" to s.progress.toFloat() / s.max.toFloat()))
                    }
                })
            }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val sb = view as? SeekBar ?: return
        changeHandlers.remove(sb)
        throttles.remove(sb)?.cancel()
        sb.setOnSeekBarChangeListener(null)
    }
}
