package com.vuenative.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.CheckBox
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.SeekBar
import android.widget.TextView
import androidx.appcompat.widget.SwitchCompat
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import androidx.test.core.app.ApplicationProvider
import com.google.android.flexbox.FlexDirection
import com.google.android.flexbox.FlexboxLayout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ComponentFactoryTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
    }

    // =========================================================================
    // VViewFactory
    // =========================================================================

    @Test
    fun testVViewFactoryCreatesFlexboxLayout() {
        val factory = VViewFactory()
        val view = factory.createView(context)

        assertNotNull("VViewFactory should create a view", view)
        assertTrue("VViewFactory should create a FlexboxLayout", view is FlexboxLayout)
    }

    @Test
    fun testVViewFactoryDefaultFlexDirection() {
        val factory = VViewFactory()
        val view = factory.createView(context) as FlexboxLayout

        assertEquals(
            "Default flexDirection should be COLUMN",
            FlexDirection.COLUMN,
            view.flexDirection
        )
    }

    @Test
    fun testVViewFactoryUpdateProp() {
        val factory = VViewFactory()
        val view = factory.createView(context)

        factory.updateProp(view, "opacity", 0.5)
        assertEquals(0.5f, view.alpha, 0.01f)
    }

    @Test
    fun testVViewFactoryInsertChild() {
        val factory = VViewFactory()
        val parent = factory.createView(context) as FlexboxLayout
        val child = View(context)

        factory.insertChild(parent, child, 0)
        assertEquals("Parent should have 1 child", 1, parent.childCount)
        assertEquals("Child should be at index 0", child, parent.getChildAt(0))
    }

    @Test
    fun testVViewFactoryRemoveChild() {
        val factory = VViewFactory()
        val parent = factory.createView(context) as FlexboxLayout
        val child = View(context)

        factory.insertChild(parent, child, 0)
        assertEquals(1, parent.childCount)

        factory.removeChild(parent, child)
        assertEquals("Parent should have 0 children", 0, parent.childCount)
    }

    @Test
    fun testVViewFactoryPressEvent() {
        val factory = VViewFactory()
        val view = factory.createView(context)
        var pressed = false

        factory.addEventListener(view, "press") { pressed = true }
        view.performClick()
        assertTrue("Press handler should be called", pressed)

        pressed = false
        factory.removeEventListener(view, "press")
        view.performClick()
        // After removing, the click listener is null so performClick still returns
        // but our handler should not be called
    }

    // =========================================================================
    // VTextFactory
    // =========================================================================

    @Test
    fun testVTextFactoryCreatesTextView() {
        val factory = VTextFactory()
        val view = factory.createView(context)

        assertNotNull("VTextFactory should create a view", view)
        assertTrue("VTextFactory should create a TextView", view is TextView)
    }

    @Test
    fun testVTextFactoryDefaultTextSize() {
        val factory = VTextFactory()
        val view = factory.createView(context) as TextView

        assertEquals(14f, view.textSize, 1f)
    }

    @Test
    fun testVTextFactoryUpdateText() {
        val factory = VTextFactory()
        val view = factory.createView(context) as TextView

        factory.updateProp(view, "text", "Hello World")
        assertEquals("Hello World", view.text.toString())
    }

    @Test
    fun testVTextFactoryUpdateTextNull() {
        val factory = VTextFactory()
        val view = factory.createView(context) as TextView

        factory.updateProp(view, "text", null)
        assertEquals("", view.text.toString())
    }

    @Test
    fun testVTextFactoryNumberOfLines() {
        val factory = VTextFactory()
        val view = factory.createView(context) as TextView

        factory.updateProp(view, "numberOfLines", 2)
        assertEquals(2, view.maxLines)
    }

    @Test
    fun testVTextFactoryNumberOfLinesZeroMeansUnlimited() {
        val factory = VTextFactory()
        val view = factory.createView(context) as TextView

        factory.updateProp(view, "numberOfLines", 0)
        assertEquals(Int.MAX_VALUE, view.maxLines)
    }

    // =========================================================================
    // VButtonFactory
    // =========================================================================

    @Test
    fun testVButtonFactoryCreatesTouchableView() {
        val factory = VButtonFactory()
        val view = factory.createView(context)

        assertNotNull("VButtonFactory should create a view", view)
        assertTrue("VButtonFactory should create a TouchableView", view is TouchableView)
    }

    @Test
    fun testVButtonFactoryDisabled() {
        val factory = VButtonFactory()
        val view = factory.createView(context) as TouchableView

        factory.updateProp(view, "disabled", true)
        assertTrue("Button should be disabled", view.isDisabled)
        assertEquals("Disabled button should have reduced alpha", 0.4f, view.alpha, 0.01f)
    }

    @Test
    fun testVButtonFactoryActiveOpacity() {
        val factory = VButtonFactory()
        val view = factory.createView(context) as TouchableView

        factory.updateProp(view, "activeOpacity", 0.3)
        assertEquals(0.3f, view.activeOpacity, 0.01f)
    }

    @Test
    fun testVButtonFactoryPressEvent() {
        val factory = VButtonFactory()
        val view = factory.createView(context) as TouchableView
        var pressed = false

        factory.addEventListener(view, "press") { pressed = true }
        view.onPress?.invoke()
        assertTrue("Press handler should be called", pressed)
    }

    @Test
    fun testVButtonFactoryRemovePressEvent() {
        val factory = VButtonFactory()
        val view = factory.createView(context) as TouchableView

        factory.addEventListener(view, "press") { }
        assertNotNull("onPress should be set", view.onPress)

        factory.removeEventListener(view, "press")
        assertTrue("onPress should be null after remove", view.onPress == null)
    }

    // =========================================================================
    // VInputFactory
    // =========================================================================

    @Test
    fun testVInputFactoryCreatesEditText() {
        val factory = VInputFactory()
        val view = factory.createView(context)

        assertNotNull("VInputFactory should create a view", view)
        assertTrue("VInputFactory should create an EditText", view is EditText)
    }

    @Test
    fun testVInputFactorySetText() {
        val factory = VInputFactory()
        val view = factory.createView(context) as EditText

        factory.updateProp(view, "text", "Hello")
        assertEquals("Hello", view.text.toString())
    }

    @Test
    fun testVInputFactorySetValue() {
        val factory = VInputFactory()
        val view = factory.createView(context) as EditText

        factory.updateProp(view, "value", "World")
        assertEquals("World", view.text.toString())
    }

    @Test
    fun testVInputFactoryPlaceholder() {
        val factory = VInputFactory()
        val view = factory.createView(context) as EditText

        factory.updateProp(view, "placeholder", "Enter text...")
        assertEquals("Enter text...", view.hint.toString())
    }

    @Test
    fun testVInputFactoryEditable() {
        val factory = VInputFactory()
        val view = factory.createView(context) as EditText

        factory.updateProp(view, "editable", false)
        assertFalse("EditText should be disabled", view.isEnabled)

        factory.updateProp(view, "editable", true)
        assertTrue("EditText should be enabled", view.isEnabled)
    }

    @Test
    fun testVInputFactoryChangeEvent() {
        val factory = VInputFactory()
        val view = factory.createView(context) as EditText
        var changedValue: String? = null

        factory.addEventListener(view, "change") { payload ->
            @Suppress("UNCHECKED_CAST")
            changedValue = (payload as? Map<String, Any?>)?.get("value") as? String
        }

        view.setText("typed text")
        assertEquals("typed text", changedValue)
    }

    @Test
    fun testVInputFactoryRemoveChangeEvent() {
        val factory = VInputFactory()
        val view = factory.createView(context) as EditText

        factory.addEventListener(view, "change") { }
        factory.removeEventListener(view, "change")

        // Should not crash and TextWatcher should be removed
        view.setText("test")
    }

    @Test
    fun testVInputFactoryFontSize() {
        val factory = VInputFactory()
        val view = factory.createView(context) as EditText

        factory.updateProp(view, "fontSize", 20)
        assertEquals(20f, view.textSize, 1f)
    }

    // =========================================================================
    // VSwitchFactory
    // =========================================================================

    @Test
    fun testVSwitchFactoryCreatesSwitchCompat() {
        val factory = VSwitchFactory()
        val view = factory.createView(context)

        assertNotNull("VSwitchFactory should create a view", view)
        assertTrue("VSwitchFactory should create a SwitchCompat", view is SwitchCompat)
    }

    @Test
    fun testVSwitchFactorySetValue() {
        val factory = VSwitchFactory()
        val view = factory.createView(context) as SwitchCompat

        factory.updateProp(view, "value", true)
        assertTrue("Switch should be checked", view.isChecked)

        factory.updateProp(view, "value", false)
        assertFalse("Switch should be unchecked", view.isChecked)
    }

    @Test
    fun testVSwitchFactoryDisabled() {
        val factory = VSwitchFactory()
        val view = factory.createView(context) as SwitchCompat

        factory.updateProp(view, "disabled", true)
        assertFalse("Switch should be disabled", view.isEnabled)
    }

    @Test
    fun testVSwitchFactoryChangeEvent() {
        val factory = VSwitchFactory()
        val view = factory.createView(context) as SwitchCompat
        var changedValue: Boolean? = null

        factory.addEventListener(view, "change") { payload ->
            @Suppress("UNCHECKED_CAST")
            changedValue = (payload as? Map<String, Any?>)?.get("value") as? Boolean
        }

        view.isChecked = true
        assertEquals(true, changedValue)
    }

    // =========================================================================
    // VImageFactory
    // =========================================================================

    @Test
    fun testVImageFactoryCreatesImageView() {
        val factory = VImageFactory()
        val view = factory.createView(context)

        assertNotNull("VImageFactory should create a view", view)
        assertTrue("VImageFactory should create an ImageView", view is ImageView)
    }

    @Test
    fun testVImageFactoryDefaultScaleType() {
        val factory = VImageFactory()
        val view = factory.createView(context) as ImageView

        assertEquals(
            "Default scaleType should be CENTER_CROP",
            ImageView.ScaleType.CENTER_CROP,
            view.scaleType
        )
    }

    @Test
    fun testVImageFactoryResizeMode() {
        val factory = VImageFactory()
        val view = factory.createView(context) as ImageView

        factory.updateProp(view, "resizeMode", "contain")
        assertEquals(ImageView.ScaleType.FIT_CENTER, view.scaleType)

        factory.updateProp(view, "resizeMode", "stretch")
        assertEquals(ImageView.ScaleType.FIT_XY, view.scaleType)

        factory.updateProp(view, "resizeMode", "center")
        assertEquals(ImageView.ScaleType.CENTER, view.scaleType)

        factory.updateProp(view, "resizeMode", "cover")
        assertEquals(ImageView.ScaleType.CENTER_CROP, view.scaleType)
    }

    // =========================================================================
    // VScrollViewFactory
    // =========================================================================

    @Test
    fun testVScrollViewFactoryCreatesSwipeRefreshLayout() {
        val factory = VScrollViewFactory()
        val view = factory.createView(context)

        assertNotNull("VScrollViewFactory should create a view", view)
        assertTrue(
            "VScrollViewFactory should create a SwipeRefreshLayout",
            view is SwipeRefreshLayout
        )
    }

    @Test
    fun testVScrollViewFactoryRefreshDisabledByDefault() {
        val factory = VScrollViewFactory()
        val view = factory.createView(context) as SwipeRefreshLayout

        assertFalse("SwipeRefreshLayout should be disabled by default", view.isEnabled)
    }

    @Test
    fun testVScrollViewFactoryInsertChild() {
        val factory = VScrollViewFactory()
        val parent = factory.createView(context)
        val child = View(context)

        factory.insertChild(parent, child, 0)

        // Access the internal content FlexboxLayout through the factory's states map
        val statesField = VScrollViewFactory::class.java.getDeclaredField("states")
        statesField.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val states = statesField.get(factory) as Map<SwipeRefreshLayout, Any>
        val scrollState = states[parent as SwipeRefreshLayout]!!
        val contentField = scrollState::class.java.getDeclaredField("content")
        contentField.isAccessible = true
        val content = contentField.get(scrollState) as FlexboxLayout
        assertEquals("Content should have 1 child", 1, content.childCount)
    }

    @Test
    fun testVScrollViewFactoryRefreshingProp() {
        val factory = VScrollViewFactory()
        val view = factory.createView(context) as SwipeRefreshLayout

        factory.updateProp(view, "refreshing", true)
        assertTrue("Should be refreshing", view.isRefreshing)

        factory.updateProp(view, "refreshing", false)
        assertFalse("Should not be refreshing", view.isRefreshing)
    }

    // =========================================================================
    // VSliderFactory
    // =========================================================================

    @Test
    fun testVSliderFactoryCreatesSeekBar() {
        val factory = VSliderFactory()
        val view = factory.createView(context)

        assertNotNull("VSliderFactory should create a view", view)
        assertTrue("VSliderFactory should create a SeekBar", view is SeekBar)
    }

    @Test
    fun testVSliderFactoryDefaults() {
        val factory = VSliderFactory()
        val view = factory.createView(context) as SeekBar

        assertEquals("Default max should be 100", 100, view.max)
        assertEquals("Default progress should be 0", 0, view.progress)
    }

    @Test
    fun testVSliderFactoryDisabled() {
        val factory = VSliderFactory()
        val view = factory.createView(context) as SeekBar

        factory.updateProp(view, "disabled", true)
        assertFalse("SeekBar should be disabled", view.isEnabled)
    }

    @Test
    fun testVSliderFactoryMaximumValue() {
        val factory = VSliderFactory()
        val view = factory.createView(context) as SeekBar

        factory.updateProp(view, "maximumValue", 200)
        assertEquals(200, view.max)
    }

    // =========================================================================
    // VActivityIndicatorFactory
    // =========================================================================

    @Test
    fun testVActivityIndicatorFactoryCreatesProgressBar() {
        val factory = VActivityIndicatorFactory()
        val view = factory.createView(context)

        assertNotNull("VActivityIndicatorFactory should create a view", view)
        assertTrue(
            "VActivityIndicatorFactory should create a ProgressBar",
            view is ProgressBar
        )
    }

    @Test
    fun testVActivityIndicatorFactoryIsIndeterminate() {
        val factory = VActivityIndicatorFactory()
        val view = factory.createView(context) as ProgressBar

        assertTrue("ProgressBar should be indeterminate", view.isIndeterminate)
    }

    @Test
    fun testVActivityIndicatorFactoryAnimatingProp() {
        val factory = VActivityIndicatorFactory()
        val view = factory.createView(context) as ProgressBar

        factory.updateProp(view, "animating", false)
        assertEquals(View.GONE, view.visibility)

        factory.updateProp(view, "animating", true)
        assertEquals(View.VISIBLE, view.visibility)
    }

    // =========================================================================
    // VCheckboxFactory
    // =========================================================================

    @Test
    fun testVCheckboxFactoryCreatesLinearLayout() {
        val factory = VCheckboxFactory()
        val view = factory.createView(context)

        assertNotNull("VCheckboxFactory should create a view", view)
        assertTrue("VCheckboxFactory should create a LinearLayout", view is LinearLayout)
    }

    @Test
    fun testVCheckboxFactoryContainsCheckboxAndLabel() {
        val factory = VCheckboxFactory()
        val view = factory.createView(context) as LinearLayout

        val checkbox = view.findViewWithTag<CheckBox>("checkbox")
        val label = view.findViewWithTag<TextView>("label")

        assertNotNull("Should contain a CheckBox", checkbox)
        assertNotNull("Should contain a label TextView", label)
    }

    @Test
    fun testVCheckboxFactorySetValue() {
        val factory = VCheckboxFactory()
        val view = factory.createView(context) as LinearLayout
        val checkbox = view.findViewWithTag<CheckBox>("checkbox")!!

        factory.updateProp(view, "value", true)
        assertTrue("Checkbox should be checked", checkbox.isChecked)

        factory.updateProp(view, "value", false)
        assertFalse("Checkbox should be unchecked", checkbox.isChecked)
    }

    @Test
    fun testVCheckboxFactorySetLabel() {
        val factory = VCheckboxFactory()
        val view = factory.createView(context) as LinearLayout
        val label = view.findViewWithTag<TextView>("label")!!

        factory.updateProp(view, "label", "Accept terms")
        assertEquals("Accept terms", label.text.toString())
        assertEquals(View.VISIBLE, label.visibility)
    }

    @Test
    fun testVCheckboxFactoryDisabled() {
        val factory = VCheckboxFactory()
        val view = factory.createView(context) as LinearLayout
        val checkbox = view.findViewWithTag<CheckBox>("checkbox")!!

        factory.updateProp(view, "disabled", true)
        assertFalse("Checkbox should be disabled", checkbox.isEnabled)
        assertEquals(0.4f, view.alpha, 0.01f)
    }

    @Test
    fun testVCheckboxFactoryChangeEvent() {
        val factory = VCheckboxFactory()
        val view = factory.createView(context) as LinearLayout
        val checkbox = view.findViewWithTag<CheckBox>("checkbox")!!
        var changedValue: Boolean? = null

        factory.addEventListener(view, "change") { payload ->
            @Suppress("UNCHECKED_CAST")
            changedValue = (payload as? Map<String, Any?>)?.get("value") as? Boolean
        }

        checkbox.isChecked = true
        assertEquals(true, changedValue)
    }

    // =========================================================================
    // VRadioFactory
    // =========================================================================

    @Test
    fun testVRadioFactoryCreatesRadioGroup() {
        val factory = VRadioFactory()
        val view = factory.createView(context)

        assertNotNull("VRadioFactory should create a view", view)
        assertTrue("VRadioFactory should create a RadioGroup", view is RadioGroup)
    }

    @Test
    fun testVRadioFactoryDefaultOrientation() {
        val factory = VRadioFactory()
        val view = factory.createView(context) as RadioGroup

        assertEquals(
            "Default orientation should be VERTICAL",
            RadioGroup.VERTICAL,
            view.orientation
        )
    }

    @Test
    fun testVRadioFactorySetOptions() {
        val factory = VRadioFactory()
        val view = factory.createView(context) as RadioGroup

        val options = listOf(
            mapOf("label" to "Option A", "value" to "a"),
            mapOf("label" to "Option B", "value" to "b"),
            mapOf("label" to "Option C", "value" to "c")
        )

        factory.updateProp(view, "options", options)
        assertEquals("Should have 3 radio buttons", 3, view.childCount)

        val first = view.getChildAt(0) as RadioButton
        assertEquals("Option A", first.text.toString())
    }

    @Test
    fun testVRadioFactoryDisabled() {
        val factory = VRadioFactory()
        val view = factory.createView(context) as RadioGroup

        val options = listOf(
            mapOf("label" to "A", "value" to "a"),
            mapOf("label" to "B", "value" to "b")
        )
        factory.updateProp(view, "options", options)

        factory.updateProp(view, "disabled", true)
        assertEquals(0.4f, view.alpha, 0.01f)
        assertFalse("First child should be disabled", view.getChildAt(0).isEnabled)
        assertFalse("Second child should be disabled", view.getChildAt(1).isEnabled)
    }
}
