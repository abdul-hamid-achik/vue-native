package com.vuenative.core

import android.content.Context
import android.graphics.Color
import android.text.Editable
import android.text.InputFilter
import android.text.InputType
import android.text.TextWatcher
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.EditText

class VInputFactory : NativeComponentFactory {
    private val changeHandlers = mutableMapOf<EditText, (Any?) -> Unit>()
    private val submitHandlers = mutableMapOf<EditText, (Any?) -> Unit>()
    private val focusHandlers = mutableMapOf<EditText, (Any?) -> Unit>()
    private val blurHandlers = mutableMapOf<EditText, (Any?) -> Unit>()
    private val textWatchers = mutableMapOf<EditText, TextWatcher>()

    override fun createView(context: Context): View {
        return EditText(context).apply {
            setBackgroundColor(Color.TRANSPARENT)
            setPadding(0, 0, 0, 0)
            textSize = 16f
            setTextColor(Color.BLACK)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    override fun updateProp(view: View, key: String, value: Any?) {
        val et = view as? EditText ?: return
        when (key) {
            "text", "value" -> {
                val newText = value?.toString() ?: ""
                if (et.text.toString() != newText) {
                    et.setText(newText)
                    et.setSelection(newText.length)
                }
            }
            "placeholder" -> et.hint = value?.toString()
            "placeholderColor", "placeholderTextColor" -> {
                val color = StyleEngine.parseColor(value)
                if (color != null) et.setHintTextColor(color)
            }
            "editable" -> et.isEnabled = value != false && value != "false"
            "keyboardType" -> {
                et.inputType = when (value) {
                    "numeric", "number-pad", "decimal-pad" ->
                        InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                    "email-address", "email" ->
                        InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
                    "phone-pad", "phone" -> InputType.TYPE_CLASS_PHONE
                    "url" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
                    else -> InputType.TYPE_CLASS_TEXT
                }
            }
            "secureTextEntry" -> {
                if (value == true || value == "true") {
                    et.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                }
            }
            "multiline" -> {
                if (value == true || value == "true") {
                    et.inputType = et.inputType or InputType.TYPE_TEXT_FLAG_MULTI_LINE
                    et.isSingleLine = false
                }
            }
            "returnKeyType" -> {
                et.imeOptions = when (value) {
                    "done" -> EditorInfo.IME_ACTION_DONE
                    "go" -> EditorInfo.IME_ACTION_GO
                    "next" -> EditorInfo.IME_ACTION_NEXT
                    "search" -> EditorInfo.IME_ACTION_SEARCH
                    "send" -> EditorInfo.IME_ACTION_SEND
                    else -> EditorInfo.IME_ACTION_DONE
                }
            }
            "maxLength" -> {
                val n = StyleEngine.toInt(value, 0)
                if (n > 0) {
                    et.filters = arrayOf(InputFilter.LengthFilter(n))
                } else {
                    // Remove length filter
                    et.filters = et.filters.filter { it !is InputFilter.LengthFilter }.toTypedArray()
                }
            }
            "autoCapitalize", "autocapitalize" -> {
                // Clear existing cap flags first
                val baseType = et.inputType and
                    (InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS or
                     InputType.TYPE_TEXT_FLAG_CAP_WORDS or
                     InputType.TYPE_TEXT_FLAG_CAP_SENTENCES).inv()
                et.inputType = when (value) {
                    "characters", "allCharacters" -> baseType or InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
                    "words" -> baseType or InputType.TYPE_TEXT_FLAG_CAP_WORDS
                    "sentences" -> baseType or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
                    "none" -> baseType
                    else -> baseType or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
                }
            }
            "autoCorrect", "autocorrect" -> {
                if (value == true || value == "true") {
                    et.inputType = et.inputType or InputType.TYPE_TEXT_FLAG_AUTO_CORRECT
                } else if (value == false || value == "false") {
                    et.inputType = et.inputType and InputType.TYPE_TEXT_FLAG_AUTO_CORRECT.inv()
                }
            }
            "textAlign", "textAlignment" -> {
                et.textAlignment = when (value) {
                    "left" -> View.TEXT_ALIGNMENT_TEXT_START
                    "center" -> View.TEXT_ALIGNMENT_CENTER
                    "right" -> View.TEXT_ALIGNMENT_TEXT_END
                    else -> View.TEXT_ALIGNMENT_TEXT_START
                }
            }
            "color" -> {
                val color = StyleEngine.parseColor(value)
                if (color != null) et.setTextColor(color)
            }
            "fontSize" -> {
                val size = when (value) {
                    is Number -> value.toFloat()
                    is String -> value.toFloatOrNull()
                    else -> null
                }
                if (size != null) et.textSize = size
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val et = view as? EditText ?: return
        when (event) {
            "change", "input", "changetext" -> {
                changeHandlers[et] = handler
                // Remove old watcher if any
                textWatchers[et]?.let { et.removeTextChangedListener(it) }
                val watcher = object : TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                    override fun afterTextChanged(s: Editable?) {
                        changeHandlers[et]?.invoke(mapOf("value" to (s?.toString() ?: "")))
                    }
                }
                textWatchers[et] = watcher
                et.addTextChangedListener(watcher)
            }
            "submit" -> {
                submitHandlers[et] = handler
                et.setOnEditorActionListener { _, _, _ ->
                    submitHandlers[et]?.invoke(mapOf("value" to et.text.toString()))
                    true
                }
            }
            "focus" -> {
                focusHandlers[et] = handler
                ensureFocusListener(et)
            }
            "blur" -> {
                blurHandlers[et] = handler
                ensureFocusListener(et)
            }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val et = view as? EditText ?: return
        when (event) {
            "change", "input", "changetext" -> {
                changeHandlers.remove(et)
                textWatchers.remove(et)?.let { et.removeTextChangedListener(it) }
            }
            "submit" -> {
                submitHandlers.remove(et)
                et.setOnEditorActionListener(null)
            }
            "focus" -> {
                focusHandlers.remove(et)
                if (blurHandlers[et] == null) {
                    et.onFocusChangeListener = null
                }
            }
            "blur" -> {
                blurHandlers.remove(et)
                if (focusHandlers[et] == null) {
                    et.onFocusChangeListener = null
                }
            }
        }
    }

    /**
     * Sets a single OnFocusChangeListener that dispatches to both focus and blur handlers.
     * This avoids the problem of one listener overwriting the other.
     */
    private fun ensureFocusListener(et: EditText) {
        et.onFocusChangeListener = View.OnFocusChangeListener { _, hasFocus ->
            if (hasFocus) {
                focusHandlers[et]?.invoke(null)
            } else {
                blurHandlers[et]?.invoke(null)
            }
        }
    }
}
