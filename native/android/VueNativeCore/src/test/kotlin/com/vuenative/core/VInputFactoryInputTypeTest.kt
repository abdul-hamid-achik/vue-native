package com.vuenative.core

import android.content.Context
import android.text.InputType
import android.widget.EditText
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * `keyboardType`, `secureTextEntry`, `multiline`, `autoCapitalize` and
 * `autoCorrect` all write `EditText.inputType`. They used to overwrite each
 * other, and because Vue does not guarantee prop order inside one bridge batch,
 * `<VInput secureTextEntry keyboardType="email-address">` produced either a
 * plain-text keyboard or a *visible* password depending on which prop arrived
 * last. These tests pin the order-independence and the caret behaviour.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VInputFactoryInputTypeTest {

    private lateinit var context: Context
    private lateinit var factory: VInputFactory

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        factory = VInputFactory()
    }

    private fun newInput(): EditText = factory.createView(context) as EditText

    private fun variationOf(et: EditText) = et.inputType and InputType.TYPE_MASK_VARIATION

    private fun classOf(et: EditText) = et.inputType and InputType.TYPE_MASK_CLASS

    private fun hasFlag(et: EditText, flag: Int) = et.inputType and flag == flag

    @Test
    fun secureTextEntryAndPasswordKeyboardAreOrderIndependent() {
        val secureFirst = newInput()
        factory.updateProp(secureFirst, "secureTextEntry", true)
        factory.updateProp(secureFirst, "keyboardType", "email-address")

        val keyboardFirst = newInput()
        factory.updateProp(keyboardFirst, "keyboardType", "email-address")
        factory.updateProp(keyboardFirst, "secureTextEntry", true)

        assertEquals(
            "prop order must not change the resulting inputType",
            secureFirst.inputType,
            keyboardFirst.inputType,
        )
        assertEquals(
            "secureTextEntry must win over the email variation so the password stays masked",
            InputType.TYPE_TEXT_VARIATION_PASSWORD,
            variationOf(secureFirst),
        )
        assertEquals(InputType.TYPE_CLASS_TEXT, classOf(secureFirst))
    }

    @Test
    fun multilineAndAutoCapitalizeSurviveKeyboardTypeInAnyOrder() {
        val a = newInput()
        factory.updateProp(a, "multiline", true)
        factory.updateProp(a, "autoCapitalize", "words")
        factory.updateProp(a, "keyboardType", "default")

        val b = newInput()
        factory.updateProp(b, "keyboardType", "default")
        factory.updateProp(b, "autoCapitalize", "words")
        factory.updateProp(b, "multiline", true)

        assertEquals(a.inputType, b.inputType)
        assertEquals(true, hasFlag(b, InputType.TYPE_TEXT_FLAG_MULTI_LINE))
        assertEquals(true, hasFlag(b, InputType.TYPE_TEXT_FLAG_CAP_WORDS))
    }

    @Test
    fun autoCorrectFalseClearsTheFlagRegardlessOfOrder() {
        val a = newInput()
        factory.updateProp(a, "autoCorrect", true)
        factory.updateProp(a, "autoCorrect", false)

        val b = newInput()
        factory.updateProp(b, "autoCorrect", false)
        factory.updateProp(b, "autoCorrect", true)

        assertEquals(false, hasFlag(a, InputType.TYPE_TEXT_FLAG_AUTO_CORRECT))
        assertEquals(true, hasFlag(b, InputType.TYPE_TEXT_FLAG_AUTO_CORRECT))
    }

    @Test
    fun secureTextEntryFalseUnmasksTheField() {
        val et = newInput()
        factory.updateProp(et, "secureTextEntry", true)
        assertEquals(InputType.TYPE_TEXT_VARIATION_PASSWORD, variationOf(et))

        factory.updateProp(et, "secureTextEntry", false)
        assertEquals(
            "secureTextEntry=false previously left the field masked",
            InputType.TYPE_TEXT_VARIATION_NORMAL,
            variationOf(et),
        )
    }

    @Test
    fun numericKeyboardKeepsTheNumberClassAndDecimalFlag() {
        val et = newInput()
        factory.updateProp(et, "keyboardType", "decimal-pad")

        assertEquals(InputType.TYPE_CLASS_NUMBER, classOf(et))
        assertEquals(true, hasFlag(et, InputType.TYPE_NUMBER_FLAG_DECIMAL))
    }

    @Test
    fun keyboardTypeNoLongerWipesAccumulatedCapitalization() {
        val et = newInput()
        factory.updateProp(et, "autoCapitalize", "words")

        // keyboardType used to assign inputType outright, dropping whatever
        // autoCapitalize/autoCorrect/multiline had already contributed.
        factory.updateProp(et, "keyboardType", "email-address")

        assertEquals(InputType.TYPE_CLASS_TEXT, classOf(et))
        assertEquals(InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS, variationOf(et))
        assertEquals(true, hasFlag(et, InputType.TYPE_TEXT_FLAG_CAP_WORDS))
    }

    @Test
    fun capFlagSetBeforeANumericKeyboardIsReappliedWhenTextReturns() {
        val et = newInput()
        factory.updateProp(et, "autoCapitalize", "words")
        factory.updateProp(et, "keyboardType", "decimal-pad")
        assertEquals(InputType.TYPE_CLASS_NUMBER, classOf(et))

        factory.updateProp(et, "keyboardType", "default")

        assertEquals(InputType.TYPE_CLASS_TEXT, classOf(et))
        // The text and number flag namespaces overlap by design
        // (TYPE_TEXT_FLAG_CAP_WORDS == TYPE_NUMBER_FLAG_DECIMAL == 0x2000), so
        // this is only meaningful once the class is text again.
        assertEquals(true, hasFlag(et, InputType.TYPE_TEXT_FLAG_CAP_WORDS))
    }

    @Test
    fun controlledTextUpdateDoesNotYankACaretThatIsNotAtTheEnd() {
        val et = newInput()
        factory.updateProp(et, "text", "hello world")
        et.setSelection(5)

        // Vue re-sends `text` on every controlled update, i.e. after every
        // keystroke. This used to call setSelection(newText.length) every time.
        factory.updateProp(et, "text", "hello there world")

        assertEquals(5, et.selectionStart)
        assertEquals(5, et.selectionEnd)
    }

    @Test
    fun controlledTextUpdateKeepsTheCaretAtTheEndWhenItWasAlreadyThere() {
        val et = newInput()
        factory.updateProp(et, "text", "abc")
        et.setSelection(3)

        factory.updateProp(et, "text", "abcd")

        assertEquals(4, et.selectionStart)
    }

    @Test
    fun caretIsClampedWhenTheNewTextIsShorter() {
        val et = newInput()
        factory.updateProp(et, "text", "hello world")
        et.setSelection(8)

        factory.updateProp(et, "text", "hi")

        assertEquals(2, et.selectionStart)
        assertEquals(2, et.selectionEnd)
    }

    @Test
    fun destroyViewReleasesTheAccumulatedInputTypeState() {
        val et = newInput()
        factory.updateProp(et, "keyboardType", "email-address")
        factory.destroyView(et)

        val states = VInputFactory::class.java.getDeclaredField("inputTypeStates")
        states.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val map = states.get(factory) as Map<EditText, Any>
        assertEquals("inputType state must not outlive the view", false, map.containsKey(et))
    }
}
