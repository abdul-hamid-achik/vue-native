package com.vuenative.core

import android.content.Context
import android.os.Build
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.DatePicker
import android.widget.LinearLayout
import android.widget.TimePicker
import java.util.Calendar

/**
 * Date/time picker that keeps the public epoch-millisecond contract consistent
 * across date, time, and date-time modes. Android has separate DatePicker and
 * TimePicker controls, so this factory composes them in one native container.
 */
class VPickerFactory : NativeComponentFactory {
    private enum class PickerMode { DATE, TIME, DATE_TIME }

    private data class PickerState(
        var mode: PickerMode = PickerMode.DATE,
        var valueMillis: Long = System.currentTimeMillis(),
        var minimumDate: Long? = null,
        var maximumDate: Long? = null,
        var minuteInterval: Int = 1,
        var isApplying: Boolean = false,
        var warnedAboutTimeBounds: Boolean = false,
    )

    private val states = mutableMapOf<PickerView, PickerState>()
    private val changeHandlers = mutableMapOf<PickerView, (Any?) -> Unit>()

    override fun createView(context: Context): View {
        val picker = PickerView(context)
        states[picker] = PickerState()

        picker.datePicker.init(
            picker.datePicker.year,
            picker.datePicker.month,
            picker.datePicker.dayOfMonth,
        ) { _, year, month, day -> onDateChanged(picker, year, month, day) }
        picker.timePicker.setOnTimeChangedListener { _, hour, minute ->
            onTimeChanged(picker, hour, minute)
        }
        applyState(picker)
        return picker
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val picker = view as? PickerView ?: return
        val state = states.getOrPut(picker) { PickerState() }

        when (key) {
            "mode" -> {
                state.mode = parseMode(value)
                applyState(picker)
            }
            "value" -> {
                state.valueMillis = epochMillis(value, System.currentTimeMillis())
                applyState(picker)
            }
            "minimumDate" -> {
                state.minimumDate = value?.let { epochMillis(it, 0L) }
                applyState(picker)
            }
            "maximumDate" -> {
                state.maximumDate = value?.let { epochMillis(it, Long.MAX_VALUE) }
                applyState(picker)
            }
            "minuteInterval" -> {
                val requested = epochMillis(value, 1L).toInt()
                state.minuteInterval = validMinuteInterval(requested)
                applyState(picker)
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        if (event == "change") {
            (view as? PickerView)?.let { changeHandlers[it] = handler }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        if (event == "change") {
            (view as? PickerView)?.let { changeHandlers.remove(it) }
        }
    }

    override fun destroyView(view: View) {
        val picker = view as? PickerView ?: return
        changeHandlers.remove(picker)
        states.remove(picker)
        picker.timePicker.setOnTimeChangedListener(null)
    }

    private fun applyState(picker: PickerView) {
        val state = states[picker] ?: return
        state.isApplying = true
        try {
            picker.datePicker.visibility = if (state.mode == PickerMode.TIME) View.GONE else View.VISIBLE
            picker.timePicker.visibility = if (state.mode == PickerMode.DATE) View.GONE else View.VISIBLE

            applyDateBounds(picker, state)
            if (state.mode == PickerMode.TIME &&
                (state.minimumDate != null || state.maximumDate != null) &&
                !state.warnedAboutTimeBounds
            ) {
                // Absolute date limits cannot be represented by a time-only Android
                // control. Make the limitation visible rather than silently treating
                // the time picker as a date picker.
                Log.w(TAG, "VPicker time mode cannot enforce absolute minimumDate/maximumDate")
                state.warnedAboutTimeBounds = true
            }

            state.valueMillis = clampToDateBounds(state, state.valueMillis)
            setControlsFromValue(picker, state.valueMillis, state.minuteInterval)
        } finally {
            state.isApplying = false
        }
    }

    private fun applyDateBounds(picker: PickerView, state: PickerState) {
        val minimum = state.minimumDate ?: picker.defaultMinimumDate
        val maximum = state.maximumDate ?: picker.defaultMaximumDate
        if (minimum > maximum) {
            Log.w(TAG, "Ignoring VPicker date bounds where minimumDate is after maximumDate")
            return
        }

        // DatePicker validates each assignment against the other current bound.
        // Widen first, then apply the requested range so updates are safe when a
        // new range is disjoint from the previous one.
        val datePicker = picker.datePicker
        datePicker.maxDate = maxOf(datePicker.maxDate, maximum)
        datePicker.minDate = minOf(datePicker.minDate, minimum)
        datePicker.maxDate = maximum
        datePicker.minDate = minimum
    }

    private fun onDateChanged(picker: PickerView, year: Int, month: Int, day: Int) {
        val state = states[picker] ?: return
        if (state.isApplying) return

        val calendar = calendarFor(state.valueMillis)
        calendar.set(Calendar.YEAR, year)
        calendar.set(Calendar.MONTH, month)
        calendar.set(Calendar.DAY_OF_MONTH, day)
        state.valueMillis = clampToDateBounds(state, calendar.timeInMillis)
        dispatchChange(picker, state)
    }

    private fun onTimeChanged(picker: PickerView, hour: Int, minute: Int) {
        val state = states[picker] ?: return
        if (state.isApplying) return

        val snappedMinute = minute - (minute % state.minuteInterval)
        if (snappedMinute != minute) {
            state.isApplying = true
            try {
                setTime(picker.timePicker, hour, snappedMinute)
            } finally {
                state.isApplying = false
            }
        }

        val calendar = Calendar.getInstance().apply {
            set(Calendar.YEAR, picker.datePicker.year)
            set(Calendar.MONTH, picker.datePicker.month)
            set(Calendar.DAY_OF_MONTH, picker.datePicker.dayOfMonth)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, snappedMinute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        state.valueMillis = clampToDateBounds(state, calendar.timeInMillis)
        dispatchChange(picker, state)
    }

    private fun dispatchChange(picker: PickerView, state: PickerState) {
        changeHandlers[picker]?.invoke(mapOf("value" to state.valueMillis.toDouble()))
    }

    private fun setControlsFromValue(picker: PickerView, valueMillis: Long, minuteInterval: Int) {
        val calendar = calendarFor(valueMillis)
        picker.datePicker.updateDate(
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH),
            calendar.get(Calendar.DAY_OF_MONTH),
        )
        val minute = calendar.get(Calendar.MINUTE) - (calendar.get(Calendar.MINUTE) % minuteInterval)
        setTime(picker.timePicker, calendar.get(Calendar.HOUR_OF_DAY), minute)
    }

    private fun clampToDateBounds(state: PickerState, valueMillis: Long): Long {
        val minimum = state.minimumDate
        val maximum = state.maximumDate
        return when {
            minimum != null && valueMillis < minimum -> minimum
            maximum != null && valueMillis > maximum -> maximum
            else -> valueMillis
        }
    }

    private fun parseMode(value: Any?): PickerMode = when (value?.toString()) {
        "date" -> PickerMode.DATE
        "time" -> PickerMode.TIME
        "datetime" -> PickerMode.DATE_TIME
        else -> {
            Log.w(TAG, "Unsupported VPicker mode '$value'; using date mode")
            PickerMode.DATE
        }
    }

    private fun validMinuteInterval(requested: Int): Int {
        if (requested in 1..60 && 60 % requested == 0) return requested
        Log.w(TAG, "VPicker minuteInterval must be a divisor of 60; using 1")
        return 1
    }

    private fun epochMillis(value: Any?, default: Long): Long = when (value) {
        is Number -> value.toLong()
        is String -> value.toDoubleOrNull()?.toLong() ?: default
        else -> default
    }

    private fun calendarFor(valueMillis: Long): Calendar = Calendar.getInstance().apply {
        timeInMillis = valueMillis
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }

    @Suppress("DEPRECATION")
    private fun setTime(picker: TimePicker, hour: Int, minute: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            picker.hour = hour
            picker.minute = minute
        } else {
            picker.currentHour = hour
            picker.currentMinute = minute
        }
    }

    private class PickerView(context: Context) : LinearLayout(context) {
        val datePicker = DatePicker(context)
        val timePicker = TimePicker(context).apply { setIs24HourView(true) }
        val defaultMinimumDate: Long = datePicker.minDate
        val defaultMaximumDate: Long = datePicker.maxDate

        init {
            orientation = VERTICAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            addView(datePicker)
            addView(timePicker)
        }
    }

    private companion object {
        const val TAG = "VueNative-VPicker"
    }
}
