package com.vuenative.core

import android.content.Context
import android.graphics.Color
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.EditText

class VInputFactory : NativeComponentFactory {
    private val changeHandlers = mutableMapOf<EditText, (Any?) -> Unit>()
    private val submitHandlers = mutableMapOf<EditText, (Any?) -> Unit>()

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
            "value" -> {
                val newText = value?.toString() ?: ""
                if (et.text.toString() != newText) {
                    et.setText(newText)
                    et.setSelection(newText.length)
                }
            }
            "placeholder" -> et.hint = value?.toString()
            "placeholderTextColor" -> {
                val color = StyleEngine.parseColor(value)
                if (color != null) et.setHintTextColor(color)
            }
            "editable" -> et.isEnabled = value != false && value != "false"
            "keyboardType" -> {
                et.inputType = when (value) {
                    "numeric", "number-pad", "decimal-pad" ->
                        android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL
                    "email-address" ->
                        android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
                    "phone-pad" -> android.text.InputType.TYPE_CLASS_PHONE
                    else -> android.text.InputType.TYPE_CLASS_TEXT
                }
            }
            "secureTextEntry" -> {
                if (value == true) {
                    et.inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD
                }
            }
            "multiline" -> {
                if (value == true) {
                    et.inputType = et.inputType or android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE
                    et.isSingleLine = false
                }
            }
            "returnKeyType" -> {
                et.imeOptions = when (value) {
                    "done"   -> EditorInfo.IME_ACTION_DONE
                    "go"     -> EditorInfo.IME_ACTION_GO
                    "next"   -> EditorInfo.IME_ACTION_NEXT
                    "search" -> EditorInfo.IME_ACTION_SEARCH
                    "send"   -> EditorInfo.IME_ACTION_SEND
                    else     -> EditorInfo.IME_ACTION_DONE
                }
            }
            "maxLength" -> {
                val n = StyleEngine.toInt(value, 0)
                if (n > 0) {
                    et.filters = arrayOf(android.text.InputFilter.LengthFilter(n))
                }
            }
            "autoCapitalize" -> {
                et.inputType = when (value) {
                    "characters" -> et.inputType or android.text.InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
                    "words"      -> et.inputType or android.text.InputType.TYPE_TEXT_FLAG_CAP_WORDS
                    "sentences"  -> et.inputType or android.text.InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
                    else         -> et.inputType
                }
            }
            else -> StyleEngine.apply(key, value, view)
        }
    }

    override fun addEventListener(view: View, event: String, handler: (Any?) -> Unit) {
        val et = view as? EditText ?: return
        when (event) {
            "change", "input" -> {
                changeHandlers[et] = handler
                et.addTextChangedListener(object : TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                    override fun afterTextChanged(s: Editable?) {
                        changeHandlers[et]?.invoke(mapOf("value" to (s?.toString() ?: "")))
                    }
                })
            }
            "submit" -> {
                submitHandlers[et] = handler
                et.setOnEditorActionListener { _, _, _ ->
                    submitHandlers[et]?.invoke(mapOf("value" to et.text.toString()))
                    false
                }
            }
            "focus" -> et.setOnFocusChangeListener { _, hasFocus -> if (hasFocus) handler(null) }
            "blur"  -> et.setOnFocusChangeListener { _, hasFocus -> if (!hasFocus) handler(null) }
        }
    }

    override fun removeEventListener(view: View, event: String) {
        val et = view as? EditText ?: return
        when (event) {
            "change", "input" -> { changeHandlers.remove(et) }
            "submit" -> { submitHandlers.remove(et); et.setOnEditorActionListener(null) }
        }
    }
}
