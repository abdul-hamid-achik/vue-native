package com.vuenative.core

import android.content.Context
import android.text.Editable
import android.text.InputFilter
import android.text.InputType
import android.text.TextWatcher
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.EditText

class VInputFactory : NativeComponentFactory {

    private companion object {
        /** Default (unfocused) underline color — a neutral gray. */
        const val BASE_UNDERLINE_COLOR = 0xFF9E9E9E.toInt()
    }

    private val changeHandlers = mutableMapOf<EditText, (Any?) -> Unit>()
    private val submitHandlers = mutableMapOf<EditText, (Any?) -> Unit>()
    private val focusHandlers = mutableMapOf<EditText, (Any?) -> Unit>()
    private val blurHandlers = mutableMapOf<EditText, (Any?) -> Unit>()
    private val textWatchers = mutableMapOf<EditText, TextWatcher>()

    /**
     * Accumulated `inputType` contributors per EditText.
     *
     * `keyboardType`, `secureTextEntry`, `multiline`, `autoCapitalize` and
     * `autoCorrect` all write `EditText.inputType`, and each one used to
     * overwrite the others. Vue does not guarantee prop order inside a single
     * bridge batch, so `<VInput secureTextEntry keyboardType="email-address">`
     * produced either a plain-text keyboard or a *visible* password depending on
     * which prop arrived last. Every prop now mutates this state and the
     * resulting `inputType` is recomputed from scratch, making the outcome
     * order-independent.
     */
    private class InputTypeState {
        var typeClass: Int = InputType.TYPE_CLASS_TEXT
        var variation: Int = 0
        var capFlag: Int = 0
        var autoCorrect: Boolean? = null
        var secure = false
        var multiline = false

        /** Flags this class does not model (e.g. NO_SUGGESTIONS) — preserved verbatim. */
        var extraFlags: Int = 0

        companion object {
            private val CAP_MASK = InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS or
                InputType.TYPE_TEXT_FLAG_CAP_WORDS or
                InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            private val MODELLED_FLAGS = CAP_MASK or
                InputType.TYPE_TEXT_FLAG_AUTO_CORRECT or
                InputType.TYPE_TEXT_FLAG_MULTI_LINE

            /**
             * Seed the state from the editor's current `inputType` so the first
             * prop we handle does not silently drop the platform default (an
             * `EditText` created in code is multi-line text) or a flag set
             * through [StyleEngine].
             */
            fun from(inputType: Int): InputTypeState = InputTypeState().apply {
                typeClass = inputType and InputType.TYPE_MASK_CLASS
                val variationBits = inputType and InputType.TYPE_MASK_VARIATION
                secure = variationBits == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                    variationBits == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD
                variation = if (secure) 0 else variationBits
                multiline = inputType and InputType.TYPE_TEXT_FLAG_MULTI_LINE != 0
                // The text and number flag namespaces overlap by design
                // (CAP_WORDS == NUMBER_FLAG_DECIMAL == 0x2000), so cap flags must
                // only be read out of a text-class type — otherwise a number
                // keyboard's DECIMAL flag would resurface as CAP_WORDS if a later
                // keyboardType switched the field back to text.
                capFlag = if (typeClass == InputType.TYPE_CLASS_TEXT) {
                    inputType and CAP_MASK
                } else {
                    0
                }
                autoCorrect =
                    if (inputType and InputType.TYPE_TEXT_FLAG_AUTO_CORRECT != 0) true else null
                extraFlags = inputType and InputType.TYPE_MASK_FLAGS and MODELLED_FLAGS.inv()
            }
        }
    }

    private val inputTypeStates = mutableMapOf<EditText, InputTypeState>()

    private fun stateFor(et: EditText): InputTypeState =
        inputTypeStates.getOrPut(et) { InputTypeState.from(et.inputType) }

    /**
     * Fold [state] into a single `inputType` and apply it. Text-only flags
     * (capitalization, autocorrect, multiline, password variation) are dropped
     * for non-text classes such as `TYPE_CLASS_NUMBER` / `TYPE_CLASS_PHONE`,
     * where Android ignores or misbehaves on them.
     */
    private fun applyInputType(et: EditText, state: InputTypeState) {
        var type = state.typeClass or state.extraFlags
        if (state.typeClass == InputType.TYPE_CLASS_TEXT) {
            // Secure entry *replaces* the variation rather than adding to it —
            // PASSWORD (0x80) and e.g. EMAIL_ADDRESS (0x20) are mutually
            // exclusive values of the same 0xff0 field, so ORing both would
            // produce 0xA0, which is not a variation Android recognises and
            // leaves the password visible.
            type = type or if (state.secure) {
                InputType.TYPE_TEXT_VARIATION_PASSWORD
            } else {
                state.variation
            }
            if (state.multiline) type = type or InputType.TYPE_TEXT_FLAG_MULTI_LINE
            type = type or state.capFlag
            when (state.autoCorrect) {
                true -> type = type or InputType.TYPE_TEXT_FLAG_AUTO_CORRECT
                false -> type = type and InputType.TYPE_TEXT_FLAG_AUTO_CORRECT.inv()
                null -> Unit
            }
        } else {
            type = type or state.variation
        }
        et.inputType = type
        // TextView.setInputType() derives single-line mode from
        // TYPE_TEXT_FLAG_MULTI_LINE, so isSingleLine must not be assigned
        // separately — doing so would strip/add MULTILINE behind this state's
        // back and reintroduce the order dependency this class removes.
    }

    /** Mutate the accumulated state and recompute `inputType` in one step. */
    private fun updateInputType(et: EditText, mutate: InputTypeState.() -> Unit) {
        val state = stateFor(et)
        state.mutate()
        applyInputType(et, state)
    }

    override fun createView(context: Context): View {
        val density = context.resources.displayMetrics.density
        val baseUnderline = (1 * density).toInt().coerceAtLeast(1)
        val focusedUnderline = (2 * density).toInt().coerceAtLeast(2)
        val verticalPadding = (8 * density).toInt()
        return EditText(context).apply {
            // Material-style underline that thickens/recolors on focus instead of
            // a bare transparent box (visible focus affordance).
            background = UnderlineDrawable(
                baseColor = BASE_UNDERLINE_COLOR,
                focusedColor = ThemeColors.accentColor(context),
                baseHeightPx = baseUnderline,
                focusedHeightPx = focusedUnderline,
            )
            setPadding(0, verticalPadding, 0, verticalPadding)
            textSize = 16f
            setTextColor(ThemeColors.defaultTextColor(context))
            // Material minimum touch target.
            minimumHeight = (48 * density).toInt()
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
                val oldText = et.text?.toString() ?: ""
                if (oldText != newText) {
                    // setText() collapses the selection to offset 0. Vue re-sends
                    // `text` on every controlled update (i.e. after every
                    // keystroke), so unconditionally calling
                    // setSelection(newText.length) yanks the caret to the end
                    // while the user is editing mid-string. Only restore the
                    // end position when the caret was already there; otherwise
                    // clamp the previous selection into the new text.
                    val selStart = et.selectionStart
                    val selEnd = et.selectionEnd
                    val caretWasAtEnd = selStart == oldText.length && selEnd == oldText.length
                    et.setText(newText)
                    if (caretWasAtEnd) {
                        et.setSelection(newText.length)
                    } else {
                        et.setSelection(
                            selStart.coerceIn(0, newText.length),
                            selEnd.coerceIn(0, newText.length),
                        )
                    }
                }
            }
            "placeholder" -> et.hint = value?.toString()
            "placeholderColor", "placeholderTextColor" -> {
                val color = StyleEngine.parseColor(value)
                if (color != null) et.setHintTextColor(color)
            }
            "editable" -> et.isEnabled = value != false && value != "false"
            "keyboardType" -> updateInputType(et) {
                when (value) {
                    "numeric", "number-pad", "decimal-pad" -> {
                        typeClass = InputType.TYPE_CLASS_NUMBER
                        variation = InputType.TYPE_NUMBER_FLAG_DECIMAL
                    }
                    "email-address", "email" -> {
                        typeClass = InputType.TYPE_CLASS_TEXT
                        variation = InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
                    }
                    "phone-pad", "phone" -> {
                        typeClass = InputType.TYPE_CLASS_PHONE
                        variation = 0
                    }
                    "url" -> {
                        typeClass = InputType.TYPE_CLASS_TEXT
                        variation = InputType.TYPE_TEXT_VARIATION_URI
                    }
                    else -> {
                        typeClass = InputType.TYPE_CLASS_TEXT
                        variation = 0
                    }
                }
            }
            "secureTextEntry" -> updateInputType(et) {
                secure = value == true || value == "true"
            }
            "multiline" -> updateInputType(et) {
                multiline = value == true || value == "true"
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
            "autoCapitalize", "autocapitalize" -> updateInputType(et) {
                capFlag = when (value) {
                    "characters", "allCharacters" -> InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
                    "words" -> InputType.TYPE_TEXT_FLAG_CAP_WORDS
                    "sentences" -> InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
                    "none" -> 0
                    else -> InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
                }
            }
            "autoCorrect", "autocorrect" -> updateInputType(et) {
                autoCorrect = when (value) {
                    true, "true" -> true
                    false, "false" -> false
                    else -> autoCorrect
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

    override fun destroyView(view: View) {
        val et = view as? EditText ?: return
        textWatchers.remove(et)?.let { et.removeTextChangedListener(it) }
        et.setOnEditorActionListener(null)
        et.onFocusChangeListener = null
        changeHandlers.remove(et)
        submitHandlers.remove(et)
        focusHandlers.remove(et)
        blurHandlers.remove(et)
        inputTypeStates.remove(et)
    }
}
