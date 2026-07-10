package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.SeekBar
import kotlin.math.roundToInt
import kotlin.math.roundToLong

/**
 * Maps the cross-platform floating-point slider contract onto Android's
 * integer-progress SeekBar. SeekBar's native minimum API is unavailable on
 * older supported Android releases, so every range is represented internally
 * as 0..N and converted at the bridge boundary.
 */
class VSliderFactory : NativeComponentFactory {
    private data class SliderState(
        var minimum: Double = 0.0,
        var maximum: Double = 1.0,
        var value: Double = 0.0,
        var step: Double? = null,
    )

    companion object {
        private const val DEFAULT_PROGRESS_RESOLUTION = 10_000
        private const val MAX_PROGRESS_RESOLUTION = 100_000
    }

    private val states = mutableMapOf<SeekBar, SliderState>()
    private val changeHandlers = mutableMapOf<SeekBar, (Any?) -> Unit>()
    private val throttles = mutableMapOf<SeekBar, EventThrottle>()

    override fun createView(context: Context): View {
        return SeekBar(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            states[this] = SliderState()
            applyState(this)
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val slider = view as? SeekBar ?: return
        val state = states.getOrPut(slider) { SliderState() }

        when (key) {
            "value" -> {
                state.value = number(value, state.minimum)
                applyState(slider)
            }
            "minimumValue", "min" -> {
                state.minimum = number(value, 0.0)
                if (state.maximum < state.minimum) state.maximum = state.minimum
                applyState(slider)
            }
            "maximumValue", "max" -> {
                state.maximum = number(value, 1.0).coerceAtLeast(state.minimum)
                applyState(slider)
            }
            "step" -> {
                val candidate = number(value, 0.0)
                state.step = candidate.takeIf { it > 0.0 }
                applyState(slider)
            }
            "minimumTrackTintColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                slider.progressTintList = android.content.res.ColorStateList.valueOf(color)
            }
            "maximumTrackTintColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                slider.progressBackgroundTintList = android.content.res.ColorStateList.valueOf(color)
            }
            "thumbTintColor" -> {
                val color = StyleEngine.parseColor(value) ?: return
                slider.thumbTintList = android.content.res.ColorStateList.valueOf(color)
            }
            "disabled" -> slider.isEnabled = value != true && value != "true"
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val slider = view as? SeekBar ?: return
        if (event !in setOf("change", "valueChange")) return

        changeHandlers[slider] = handler
        throttles.remove(slider)?.cancel()
        val throttle = EventThrottle(intervalMs = 16L, handler = handler)
        throttles[slider] = throttle
        slider.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
                if (!fromUser) return
                val value = valueForProgress(seekBar, progress)
                states[seekBar]?.value = value
                throttle.fire(mapOf("value" to value))
            }

            override fun onStartTrackingTouch(seekBar: SeekBar) = Unit

            override fun onStopTrackingTouch(seekBar: SeekBar) {
                // Always deliver the final value immediately on release.
                throttle.cancel()
                val value = valueForProgress(seekBar, seekBar.progress)
                states[seekBar]?.value = value
                changeHandlers[seekBar]?.invoke(mapOf("value" to value))
            }
        })
    }

    override fun removeEventListener(view: View, event: String) {
        val slider = view as? SeekBar ?: return
        if (event !in setOf("change", "valueChange")) return
        changeHandlers.remove(slider)
        throttles.remove(slider)?.cancel()
        slider.setOnSeekBarChangeListener(null)
    }

    override fun destroyView(view: View) {
        val slider = view as? SeekBar ?: return
        removeEventListener(slider, "change")
        states.remove(slider)
    }

    /** Visible to same-module tests; this is the native-to-JS conversion contract. */
    internal fun valueForProgress(slider: SeekBar, progress: Int): Double {
        val state = states[slider] ?: SliderState()
        val range = state.maximum - state.minimum
        if (range <= 0.0 || slider.max <= 0) return state.minimum
        val fraction = progress.toDouble().coerceIn(0.0, slider.max.toDouble()) / slider.max.toDouble()
        return snapAndClamp(state, state.minimum + range * fraction)
    }

    private fun applyState(slider: SeekBar) {
        val state = states.getOrPut(slider) { SliderState() }
        if (state.maximum < state.minimum) state.maximum = state.minimum
        slider.max = progressResolution(state)
        val normalized = snapAndClamp(state, state.value)
        state.value = normalized
        slider.progress = progressForValue(state, slider.max, normalized)
    }

    private fun progressResolution(state: SliderState): Int {
        val range = state.maximum - state.minimum
        val step = state.step
        if (range > 0.0 && step != null) {
            val increments = (range / step).roundToLong()
            if (increments in 1..MAX_PROGRESS_RESOLUTION.toLong()) return increments.toInt()
        }
        return DEFAULT_PROGRESS_RESOLUTION
    }

    private fun progressForValue(state: SliderState, maxProgress: Int, value: Double): Int {
        val range = state.maximum - state.minimum
        if (range <= 0.0 || maxProgress <= 0) return 0
        val fraction = ((value - state.minimum) / range).coerceIn(0.0, 1.0)
        return (fraction * maxProgress).roundToInt().coerceIn(0, maxProgress)
    }

    private fun snapAndClamp(state: SliderState, value: Double): Double {
        val clamped = value.coerceIn(state.minimum, state.maximum)
        val step = state.step ?: return clamped
        val snapped = state.minimum + ((clamped - state.minimum) / step).roundToLong() * step
        return snapped.coerceIn(state.minimum, state.maximum)
    }

    private fun number(value: Any?, default: Double): Double = when (value) {
        is Number -> value.toDouble()
        is String -> value.toDoubleOrNull() ?: default
        else -> default
    }
}
