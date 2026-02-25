package com.vuenative.core

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import com.google.android.flexbox.AlignItems
import com.google.android.flexbox.FlexDirection
import com.google.android.flexbox.FlexboxLayout
import com.google.android.flexbox.JustifyContent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class StyleEngineTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
    }

    // -------------------------------------------------------------------------
    // backgroundColor
    // -------------------------------------------------------------------------

    @Test
    fun testBackgroundColor() {
        val view = View(context)
        StyleEngine.apply("backgroundColor", "#ff0000", view)

        assertNotNull("Background should be set", view.background)
        assertTrue("Background should be a GradientDrawable", view.background is GradientDrawable)
    }

    // -------------------------------------------------------------------------
    // opacity
    // -------------------------------------------------------------------------

    @Test
    fun testOpacity() {
        val view = View(context)
        StyleEngine.apply("opacity", 0.5, view)

        assertEquals(0.5f, view.alpha, 0.01f)
    }

    @Test
    fun testOpacityFromInt() {
        val view = View(context)
        StyleEngine.apply("opacity", 1, view)

        assertEquals(1.0f, view.alpha, 0.01f)
    }

    // -------------------------------------------------------------------------
    // borderRadius
    // -------------------------------------------------------------------------

    @Test
    fun testBorderRadius() {
        val view = View(context)
        StyleEngine.apply("borderRadius", 10, view)

        assertNotNull("Background should be set", view.background)
        assertTrue("Background should be a GradientDrawable", view.background is GradientDrawable)
        val bg = view.background as GradientDrawable
        assertEquals(
            "Corner radius should be 10dp in px",
            StyleEngine.dpToPx(context, 10f),
            bg.cornerRadius,
            0.1f
        )
    }

    // -------------------------------------------------------------------------
    // padding
    // -------------------------------------------------------------------------

    @Test
    fun testPadding() {
        val view = View(context)
        StyleEngine.apply("padding", 16, view)

        val expectedPx = StyleEngine.dpToPx(context, 16f).toInt()
        assertEquals(expectedPx, view.paddingLeft)
        assertEquals(expectedPx, view.paddingTop)
        assertEquals(expectedPx, view.paddingRight)
        assertEquals(expectedPx, view.paddingBottom)
    }

    // -------------------------------------------------------------------------
    // paddingHorizontal / paddingVertical
    // -------------------------------------------------------------------------

    @Test
    fun testPaddingHorizontal() {
        val view = View(context)
        StyleEngine.apply("paddingHorizontal", 20, view)

        val expectedPx = StyleEngine.dpToPx(context, 20f).toInt()
        assertEquals(expectedPx, view.paddingLeft)
        assertEquals(expectedPx, view.paddingRight)
        assertEquals("Top padding should not be set", 0, view.paddingTop)
        assertEquals("Bottom padding should not be set", 0, view.paddingBottom)
    }

    @Test
    fun testPaddingVertical() {
        val view = View(context)
        StyleEngine.apply("paddingVertical", 12, view)

        val expectedPx = StyleEngine.dpToPx(context, 12f).toInt()
        assertEquals(expectedPx, view.paddingTop)
        assertEquals(expectedPx, view.paddingBottom)
        assertEquals("Left padding should not be set", 0, view.paddingLeft)
        assertEquals("Right padding should not be set", 0, view.paddingRight)
    }

    // -------------------------------------------------------------------------
    // margin (stored in FlexProps)
    // -------------------------------------------------------------------------

    @Test
    fun testMargin() {
        val view = View(context)
        StyleEngine.apply("margin", 8, view)

        val fp = StyleEngine.getFlexProps(view)
        val expectedPx = StyleEngine.dpToPx(context, 8f).toInt()
        assertEquals(expectedPx, fp.marginLeft)
        assertEquals(expectedPx, fp.marginTop)
        assertEquals(expectedPx, fp.marginRight)
        assertEquals(expectedPx, fp.marginBottom)
    }

    // -------------------------------------------------------------------------
    // width / height (stored in FlexProps)
    // -------------------------------------------------------------------------

    @Test
    fun testWidth() {
        val view = View(context)
        StyleEngine.apply("width", 100, view)

        val fp = StyleEngine.getFlexProps(view)
        val expectedPx = StyleEngine.dpToPx(context, 100f).toInt()
        assertEquals(expectedPx, fp.width)
    }

    @Test
    fun testHeight() {
        val view = View(context)
        StyleEngine.apply("height", 50, view)

        val fp = StyleEngine.getFlexProps(view)
        val expectedPx = StyleEngine.dpToPx(context, 50f).toInt()
        assertEquals(expectedPx, fp.height)
    }

    // -------------------------------------------------------------------------
    // flex
    // -------------------------------------------------------------------------

    @Test
    fun testFlex() {
        val view = View(context)
        StyleEngine.apply("flex", 1, view)

        val fp = StyleEngine.getFlexProps(view)
        assertEquals("flexGrow should be 1", 1f, fp.flexGrow, 0.01f)
        assertEquals("flexShrink should be 1", 1f, fp.flexShrink, 0.01f)
    }

    // -------------------------------------------------------------------------
    // flexDirection
    // -------------------------------------------------------------------------

    @Test
    fun testFlexDirection() {
        val flexbox = FlexboxLayout(context)
        StyleEngine.apply("flexDirection", "row", flexbox)

        assertEquals(FlexDirection.ROW, flexbox.flexDirection)
    }

    @Test
    fun testFlexDirectionColumn() {
        val flexbox = FlexboxLayout(context)
        StyleEngine.apply("flexDirection", "column", flexbox)

        assertEquals(FlexDirection.COLUMN, flexbox.flexDirection)
    }

    // -------------------------------------------------------------------------
    // justifyContent
    // -------------------------------------------------------------------------

    @Test
    fun testJustifyContent() {
        val flexbox = FlexboxLayout(context)
        StyleEngine.apply("justifyContent", "center", flexbox)

        assertEquals(JustifyContent.CENTER, flexbox.justifyContent)
    }

    @Test
    fun testJustifyContentSpaceBetween() {
        val flexbox = FlexboxLayout(context)
        StyleEngine.apply("justifyContent", "space-between", flexbox)

        assertEquals(JustifyContent.SPACE_BETWEEN, flexbox.justifyContent)
    }

    // -------------------------------------------------------------------------
    // alignItems
    // -------------------------------------------------------------------------

    @Test
    fun testAlignItems() {
        val flexbox = FlexboxLayout(context)
        StyleEngine.apply("alignItems", "center", flexbox)

        assertEquals(AlignItems.CENTER, flexbox.alignItems)
    }

    @Test
    fun testAlignItemsFlexStart() {
        val flexbox = FlexboxLayout(context)
        StyleEngine.apply("alignItems", "flex-start", flexbox)

        assertEquals(AlignItems.FLEX_START, flexbox.alignItems)
    }

    // -------------------------------------------------------------------------
    // overflow
    // -------------------------------------------------------------------------

    @Test
    fun testOverflowHidden() {
        val viewGroup = FrameLayout(context)
        StyleEngine.apply("overflow", "hidden", viewGroup)

        assertTrue("clipChildren should be true", viewGroup.clipChildren)
        assertTrue("clipToPadding should be true", viewGroup.clipToPadding)
    }

    // -------------------------------------------------------------------------
    // accessibilityLabel
    // -------------------------------------------------------------------------

    @Test
    fun testAccessibilityLabel() {
        val view = View(context)
        StyleEngine.apply("accessibilityLabel", "Submit button", view)

        assertEquals("Submit button", view.contentDescription)
        assertEquals(
            View.IMPORTANT_FOR_ACCESSIBILITY_YES,
            view.importantForAccessibility
        )
    }

    // -------------------------------------------------------------------------
    // Text properties on TextView
    // -------------------------------------------------------------------------

    @Test
    fun testTextColor() {
        val textView = TextView(context)
        StyleEngine.apply("color", "#0000ff", textView)

        assertEquals(Color.BLUE, textView.currentTextColor)
    }

    @Test
    fun testFontSize() {
        val textView = TextView(context)
        StyleEngine.apply("fontSize", 20, textView)

        // textSize is returned in px; we set it in SP
        // In Robolectric default density, 1sp = 1px
        assertEquals(20f, textView.textSize, 1f)
    }

    // -------------------------------------------------------------------------
    // Internal props
    // -------------------------------------------------------------------------

    @Test
    fun testInternalProps() {
        val view = View(context)
        StyleEngine.apply("__myProp", "hello", view)

        val stored = StyleEngine.getInternalProp("__myProp", view)
        assertEquals("hello", stored)
    }

    @Test
    fun testInternalPropsOverwrite() {
        val view = View(context)
        StyleEngine.apply("__myProp", "first", view)
        StyleEngine.apply("__myProp", "second", view)

        val stored = StyleEngine.getInternalProp("__myProp", view)
        assertEquals("second", stored)
    }

    // -------------------------------------------------------------------------
    // parseColor
    // -------------------------------------------------------------------------

    @Test
    fun testParseColorHex6() {
        val color = StyleEngine.parseColor("#ff0000")
        assertNotNull(color)
        assertEquals(Color.RED, color)
    }

    @Test
    fun testParseColorHex8() {
        val color = StyleEngine.parseColor("#80ff0000")
        assertNotNull(color)
        assertEquals(0x80, Color.alpha(color!!))
        assertEquals(0xff, Color.red(color))
        assertEquals(0x00, Color.green(color))
        assertEquals(0x00, Color.blue(color))
    }

    @Test
    fun testParseColorNamedWhite() {
        assertEquals(Color.WHITE, StyleEngine.parseColor("white"))
    }

    @Test
    fun testParseColorNamedBlack() {
        assertEquals(Color.BLACK, StyleEngine.parseColor("black"))
    }

    @Test
    fun testParseColorNamedRed() {
        assertEquals(Color.RED, StyleEngine.parseColor("red"))
    }

    @Test
    fun testParseColorTransparent() {
        assertEquals(Color.TRANSPARENT, StyleEngine.parseColor("transparent"))
    }

    @Test
    fun testParseColorNull() {
        assertNull(StyleEngine.parseColor(null))
    }

    @Test
    fun testParseColorInvalid() {
        assertNull(StyleEngine.parseColor("notacolor"))
    }

    // -------------------------------------------------------------------------
    // toFloat
    // -------------------------------------------------------------------------

    @Test
    fun testToFloatFromInt() {
        assertEquals(42f, StyleEngine.toFloat(42, 0f), 0.01f)
    }

    @Test
    fun testToFloatFromDouble() {
        assertEquals(3.14f, StyleEngine.toFloat(3.14, 0f), 0.01f)
    }

    @Test
    fun testToFloatFromString() {
        assertEquals(7.5f, StyleEngine.toFloat("7.5", 0f), 0.01f)
    }

    @Test
    fun testToFloatFromNull() {
        assertEquals(99f, StyleEngine.toFloat(null, 99f), 0.01f)
    }

    @Test
    fun testToFloatFromInvalidString() {
        assertEquals(5f, StyleEngine.toFloat("abc", 5f), 0.01f)
    }

    // -------------------------------------------------------------------------
    // toInt
    // -------------------------------------------------------------------------

    @Test
    fun testToIntFromInt() {
        assertEquals(42, StyleEngine.toInt(42, 0))
    }

    @Test
    fun testToIntFromDouble() {
        assertEquals(3, StyleEngine.toInt(3.7, 0))
    }

    @Test
    fun testToIntFromString() {
        assertEquals(10, StyleEngine.toInt("10", 0))
    }

    @Test
    fun testToIntFromNull() {
        assertEquals(99, StyleEngine.toInt(null, 99))
    }

    // -------------------------------------------------------------------------
    // dpToPx
    // -------------------------------------------------------------------------

    @Test
    fun testDpToPx() {
        val density = context.resources.displayMetrics.density
        val result = StyleEngine.dpToPx(context, 10f)
        assertEquals(10f * density, result, 0.01f)
    }

    @Test
    fun testDpToPxZero() {
        assertEquals(0f, StyleEngine.dpToPx(context, 0f), 0.01f)
    }

    // -------------------------------------------------------------------------
    // spToPx
    // -------------------------------------------------------------------------

    @Test
    fun testSpToPx() {
        val result = StyleEngine.spToPx(context, 14f)
        assertTrue("spToPx should return a positive value for positive input", result > 0f)
    }

    // -------------------------------------------------------------------------
    // display: none / visible
    // -------------------------------------------------------------------------

    @Test
    fun testDisplayNone() {
        val view = View(context)
        StyleEngine.apply("display", "none", view)
        assertEquals(View.GONE, view.visibility)
    }

    @Test
    fun testDisplayFlex() {
        val view = View(context)
        view.visibility = View.GONE
        StyleEngine.apply("display", "flex", view)
        assertEquals(View.VISIBLE, view.visibility)
    }

    // -------------------------------------------------------------------------
    // elevation
    // -------------------------------------------------------------------------

    @Test
    fun testElevation() {
        val view = View(context)
        StyleEngine.apply("elevation", 4, view)

        val expectedPx = StyleEngine.dpToPx(context, 4f)
        assertEquals(expectedPx, view.elevation, 0.1f)
    }
}
