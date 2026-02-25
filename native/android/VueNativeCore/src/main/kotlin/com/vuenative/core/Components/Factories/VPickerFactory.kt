package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.DatePicker
import java.util.Calendar

class VPickerFactory : NativeComponentFactory {
    private val changeHandlers = mutableMapOf<View, (Any?) -> Unit>()

    override fun createView(context: Context): View {
        return DatePicker(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val dp = view as? DatePicker ?: return
        when (key) {
            "value" -> {
                val ms = StyleEngine.toFloat(value, 0f).toLong()
                val cal = Calendar.getInstance().apply { timeInMillis = ms }
                dp.updateDate(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH))
            }
            "minimumDate" -> {
                val ms = StyleEngine.toFloat(value, 0f).toLong()
                dp.minDate = ms
            }
            "maximumDate" -> {
                val ms = StyleEngine.toFloat(value, 0f).toLong()
                dp.maxDate = ms
            }
            "mode" -> {} // DatePicker handles date mode; TimePicker for time
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val dp = view as? DatePicker ?: return
        if (event == "change") {
            changeHandlers[view] = handler
            dp.init(
                dp.year, dp.month, dp.dayOfMonth
            ) { _, year, month, day ->
                val cal = Calendar.getInstance().apply { set(year, month, day) }
                changeHandlers[view]?.invoke(mapOf("value" to cal.timeInMillis.toDouble()))
            }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        changeHandlers.remove(view)
    }
}
