package com.vuenative.core

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import com.google.android.flexbox.AlignContent
import com.google.android.flexbox.AlignItems
import com.google.android.flexbox.AlignSelf
import com.google.android.flexbox.FlexDirection
import com.google.android.flexbox.FlexWrap
import com.google.android.flexbox.FlexboxLayout
import com.google.android.flexbox.JustifyContent

/**
 * Converts JS style props to Android View properties.
 * Numbers are treated as dp (density-independent pixels).
 * Colors are hex strings like "#RRGGBB" or "#AARRGGBB".
 */
object StyleEngine {

    fun apply(key: String, value: Any?, view: View) {
        val ctx = view.context
        when (key) {
            // --- Background & Visual ---
            "backgroundColor" -> {
                val color = parseColor(value) ?: return
                ensureBackground(view).setColor(color)
                view.background = view.background
                view.invalidate()
            }
            "opacity" -> view.alpha = toFloat(value, 1f)
            "overflow" -> {
                if (value == "hidden") {
                    (view as? ViewGroup)?.clipChildren = true
                    (view as? ViewGroup)?.clipToPadding = true
                }
            }

            // --- Border ---
            "borderRadius" -> {
                val px = dpToPx(ctx, toFloat(value, 0f))
                ensureBackground(view).cornerRadius = px
                view.background = view.background
            }
            "borderTopLeftRadius", "borderTopRightRadius",
            "borderBottomLeftRadius", "borderBottomRightRadius" -> {
                val px = dpToPx(ctx, toFloat(value, 0f))
                val bg = ensureBackground(view)
                val radii = bg.cornerRadii ?: FloatArray(8) { 0f }
                when (key) {
                    "borderTopLeftRadius"     -> { radii[0] = px; radii[1] = px }
                    "borderTopRightRadius"    -> { radii[2] = px; radii[3] = px }
                    "borderBottomRightRadius" -> { radii[4] = px; radii[5] = px }
                    "borderBottomLeftRadius"  -> { radii[6] = px; radii[7] = px }
                }
                bg.cornerRadii = radii
                view.background = view.background
            }
            "borderWidth" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                val color = (view.getTag(TAG_BORDER_COLOR) as? Int) ?: Color.TRANSPARENT
                ensureBackground(view).setStroke(px, color)
                view.background = view.background
            }
            "borderColor" -> {
                val color = parseColor(value) ?: return
                view.setTag(TAG_BORDER_COLOR, color)
                val width = (view.getTag(TAG_BORDER_WIDTH) as? Int) ?: 1
                ensureBackground(view).setStroke(width, color)
                view.background = view.background
            }
            "borderBottomWidth" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                val pad = view.paddingBottom
                view.setPadding(view.paddingLeft, view.paddingTop, view.paddingRight, pad + px)
            }
            "borderTopWidth" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                view.setPadding(view.paddingLeft, view.paddingTop + px, view.paddingRight, view.paddingBottom)
            }

            // --- Padding ---
            "padding" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                view.setPadding(px, px, px, px)
            }
            "paddingHorizontal" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                view.setPadding(px, view.paddingTop, px, view.paddingBottom)
            }
            "paddingVertical" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                view.setPadding(view.paddingLeft, px, view.paddingRight, px)
            }
            "paddingLeft", "paddingStart" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                view.setPadding(px, view.paddingTop, view.paddingRight, view.paddingBottom)
            }
            "paddingRight", "paddingEnd" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                view.setPadding(view.paddingLeft, view.paddingTop, px, view.paddingBottom)
            }
            "paddingTop" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                view.setPadding(view.paddingLeft, px, view.paddingRight, view.paddingBottom)
            }
            "paddingBottom" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                view.setPadding(view.paddingLeft, view.paddingTop, view.paddingRight, px)
            }

            // --- Margin (stored in FlexProps, applied when inserted into parent) ---
            "margin" -> updateFlexProps(view) { fp -> val px = dpToPx(ctx, toFloat(value, 0f)).toInt(); fp.copy(marginLeft = px, marginTop = px, marginRight = px, marginBottom = px) }
            "marginHorizontal" -> updateFlexProps(view) { fp -> val px = dpToPx(ctx, toFloat(value, 0f)).toInt(); fp.copy(marginLeft = px, marginRight = px) }
            "marginVertical"   -> updateFlexProps(view) { fp -> val px = dpToPx(ctx, toFloat(value, 0f)).toInt(); fp.copy(marginTop = px, marginBottom = px) }
            "marginLeft"       -> updateFlexProps(view) { fp -> fp.copy(marginLeft = dpToPx(ctx, toFloat(value, 0f)).toInt()) }
            "marginRight"      -> updateFlexProps(view) { fp -> fp.copy(marginRight = dpToPx(ctx, toFloat(value, 0f)).toInt()) }
            "marginTop"        -> updateFlexProps(view) { fp -> fp.copy(marginTop = dpToPx(ctx, toFloat(value, 0f)).toInt()) }
            "marginBottom"     -> updateFlexProps(view) { fp -> fp.copy(marginBottom = dpToPx(ctx, toFloat(value, 0f)).toInt()) }

            // --- Dimensions ---
            "width"  -> updateFlexProps(view) { fp -> fp.copy(width = parseDimension(ctx, value)) }
            "height" -> updateFlexProps(view) { fp -> fp.copy(height = parseDimension(ctx, value)) }
            "minWidth"  -> updateFlexProps(view) { fp -> fp.copy(minWidth = dpToPx(ctx, toFloat(value, 0f)).toInt()) }
            "minHeight" -> updateFlexProps(view) { fp -> fp.copy(minHeight = dpToPx(ctx, toFloat(value, 0f)).toInt()) }
            "maxWidth"  -> view.post { view.maxWidth = dpToPx(ctx, toFloat(value, 0f)).toInt() }

            // --- Flex props (stored in FlexProps, applied when inserted) ---
            "flex" -> {
                val f = toFloat(value, 0f)
                updateFlexProps(view) { fp -> fp.copy(flexGrow = f, flexShrink = 1f, width = 0, height = 0) }
            }
            "flexGrow"   -> updateFlexProps(view) { fp -> fp.copy(flexGrow = toFloat(value, 0f)) }
            "flexShrink" -> updateFlexProps(view) { fp -> fp.copy(flexShrink = toFloat(value, 1f)) }
            "alignSelf"  -> updateFlexProps(view) { fp -> fp.copy(alignSelf = parseAlignSelf(value)) }
            "order"      -> updateFlexProps(view) { fp -> fp.copy(order = toInt(value, 1)) }

            // --- Parent Flex props (applied to FlexboxLayout itself) ---
            "flexDirection" -> {
                (view as? FlexboxLayout)?.flexDirection = parseFlexDirection(value)
            }
            "flexWrap" -> {
                (view as? FlexboxLayout)?.flexWrap = parseFlexWrap(value)
            }
            "alignItems" -> {
                (view as? FlexboxLayout)?.alignItems = parseAlignItems(value)
            }
            "alignContent" -> {
                (view as? FlexboxLayout)?.alignContent = parseAlignContent(value)
            }
            "justifyContent" -> {
                (view as? FlexboxLayout)?.justifyContent = parseJustifyContent(value)
            }
            "gap" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                view.setTag(TAG_GAP, px)
                (view as? FlexboxLayout)?.gap = px
            }
            "rowGap" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                view.setTag(TAG_GAP, px)
                (view as? FlexboxLayout)?.rowGap = px
            }
            "columnGap" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                view.setTag(TAG_GAP, px)
                (view as? FlexboxLayout)?.columnGap = px
            }

            // --- Elevation / Shadow ---
            "elevation" -> {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                    view.elevation = dpToPx(ctx, toFloat(value, 0f))
                }
            }
            "shadowColor", "shadowOpacity", "shadowRadius", "shadowOffset" -> {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                    view.elevation = dpToPx(ctx, 2f)
                }
            }

            // --- Text props (delegated to TextView) ---
            "color", "fontSize", "fontWeight", "fontStyle", "lineHeight",
            "letterSpacing", "textAlign", "textDecorationLine", "textTransform",
            "fontFamily", "numberOfLines" -> {
                (view as? TextView)?.let { applyTextProp(it, key, value) }
            }

            // --- Visibility ---
            "display" -> {
                view.visibility = if (value == "none") View.GONE else View.VISIBLE
            }
            "visible" -> {
                if (value == false || value == "false") view.visibility = View.INVISIBLE
                else view.visibility = View.VISIBLE
            }
            "hidden" -> {
                view.visibility = if (value == true || value == "true") View.INVISIBLE else View.VISIBLE
            }

            // --- Interaction ---
            "pointerEvents" -> {
                if (value == "none") {
                    view.isClickable = false
                    view.isFocusable = false
                }
            }

            // --- Accessibility ---
            "accessibilityLabel" -> view.contentDescription = value?.toString()
            "accessible" -> view.importantForAccessibility =
                if (value == true) View.IMPORTANT_FOR_ACCESSIBILITY_YES
                else View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }

        // After updating flex props, re-apply to parent if already attached
        if (key in FLEX_LAYOUT_KEYS) {
            applyFlexPropsToParent(view)
        }
    }

    fun applyTextProp(tv: TextView, key: String, value: Any?) {
        val ctx = tv.context
        when (key) {
            "color" -> tv.setTextColor(parseColor(value) ?: Color.BLACK)
            "fontSize" -> tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, toFloat(value, 14f))
            "fontWeight" -> {
                val current = tv.typeface ?: android.graphics.Typeface.DEFAULT
                tv.setTypeface(current,
                    if (value == "bold" || (value as? Number)?.toInt() ?: 0 >= 600)
                        android.graphics.Typeface.BOLD
                    else android.graphics.Typeface.NORMAL
                )
            }
            "fontStyle" -> {
                val current = tv.typeface ?: android.graphics.Typeface.DEFAULT
                tv.setTypeface(current,
                    if (value == "italic") android.graphics.Typeface.ITALIC
                    else android.graphics.Typeface.NORMAL
                )
            }
            "textAlign" -> tv.textAlignment = when (value) {
                "center" -> View.TEXT_ALIGNMENT_CENTER
                "right"  -> View.TEXT_ALIGNMENT_VIEW_END
                "left"   -> View.TEXT_ALIGNMENT_VIEW_START
                else     -> View.TEXT_ALIGNMENT_INHERIT
            }
            "lineHeight" -> {
                val px = dpToPx(ctx, toFloat(value, 0f))
                tv.setLineSpacing(px - tv.textSize, 1f)
            }
            "letterSpacing" -> {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                    tv.letterSpacing = toFloat(value, 0f) / tv.textSize
                }
            }
            "textDecorationLine" -> {
                tv.paintFlags = when (value) {
                    "underline"    -> tv.paintFlags or android.graphics.Paint.UNDERLINE_TEXT_FLAG
                    "line-through" -> tv.paintFlags or android.graphics.Paint.STRIKE_THRU_TEXT_FLAG
                    "none"         -> tv.paintFlags and android.graphics.Paint.UNDERLINE_TEXT_FLAG.inv()
                                               and android.graphics.Paint.STRIKE_THRU_TEXT_FLAG.inv()
                    else           -> tv.paintFlags
                }
            }
            "textTransform" -> {
                val t = tv.text?.toString() ?: ""
                tv.text = when (value) {
                    "uppercase"  -> t.uppercase()
                    "lowercase"  -> t.lowercase()
                    "capitalize" -> t.split(" ").joinToString(" ") { it.replaceFirstChar(Char::uppercase) }
                    else         -> t
                }
            }
            "numberOfLines" -> {
                tv.maxLines = toInt(value, Int.MAX_VALUE).let { if (it == 0) Int.MAX_VALUE else it }
                tv.ellipsize = if (toInt(value, 0) > 0) android.text.TextUtils.TruncateAt.END else null
            }
        }
    }

    // -- Flex Props ---------------------------------------------------------------

    data class FlexProps(
        val width: Int = ViewGroup.LayoutParams.WRAP_CONTENT,
        val height: Int = ViewGroup.LayoutParams.WRAP_CONTENT,
        val marginLeft: Int = 0,
        val marginTop: Int = 0,
        val marginRight: Int = 0,
        val marginBottom: Int = 0,
        val flexGrow: Float = 0f,
        val flexShrink: Float = 1f,
        val alignSelf: Int = AlignSelf.AUTO,
        val order: Int = 1,
        val minWidth: Int = 0,
        val minHeight: Int = 0,
    )

    fun getFlexProps(view: View): FlexProps =
        view.getTag(TAG_FLEX_PROPS) as? FlexProps ?: FlexProps()

    private fun updateFlexProps(view: View, update: (FlexProps) -> FlexProps) {
        val current = getFlexProps(view)
        view.setTag(TAG_FLEX_PROPS, update(current))
    }

    fun applyFlexPropsToParent(view: View) {
        val parent = view.parent as? FlexboxLayout ?: return
        val fp = getFlexProps(view)
        val lp = FlexboxLayout.LayoutParams(fp.width, fp.height).apply {
            setMargins(fp.marginLeft, fp.marginTop, fp.marginRight, fp.marginBottom)
            flexGrow = fp.flexGrow
            flexShrink = fp.flexShrink
            alignSelf = fp.alignSelf
            order = fp.order
            minWidth = fp.minWidth
            minHeight = fp.minHeight
        }
        view.layoutParams = lp
        parent.requestLayout()
    }

    fun buildFlexLayoutParams(view: View): FlexboxLayout.LayoutParams {
        val fp = getFlexProps(view)
        return FlexboxLayout.LayoutParams(fp.width, fp.height).apply {
            setMargins(fp.marginLeft, fp.marginTop, fp.marginRight, fp.marginBottom)
            flexGrow = fp.flexGrow
            flexShrink = fp.flexShrink
            alignSelf = fp.alignSelf
            order = fp.order
            minWidth = fp.minWidth
            minHeight = fp.minHeight
        }
    }

    // -- Color parsing ------------------------------------------------------------

    fun parseColor(value: Any?): Int? {
        val s = value?.toString() ?: return null
        return try {
            when {
                s.startsWith("#") -> Color.parseColor(s)
                s.startsWith("rgb") -> {
                    val nums = s.filter { it.isDigit() || it == ',' || it == ' ' }
                        .split(",").map { it.trim().toInt() }
                    if (nums.size >= 3) Color.rgb(nums[0], nums[1], nums[2]) else null
                }
                s == "transparent" -> Color.TRANSPARENT
                s == "white" -> Color.WHITE
                s == "black" -> Color.BLACK
                s == "red" -> Color.RED
                s == "blue" -> Color.BLUE
                s == "green" -> Color.GREEN
                s == "gray" || s == "grey" -> Color.GRAY
                else -> Color.parseColor(s)
            }
        } catch (e: Exception) { null }
    }

    // -- Dimension helpers --------------------------------------------------------

    fun dpToPx(context: Context, dp: Float): Float {
        return dp * context.resources.displayMetrics.density
    }

    fun spToPx(context: Context, sp: Float): Float {
        return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, context.resources.displayMetrics)
    }

    private fun parseDimension(context: Context, value: Any?): Int {
        return when {
            value is String && value.endsWith("%") -> {
                if (value == "100%") ViewGroup.LayoutParams.MATCH_PARENT
                else ViewGroup.LayoutParams.WRAP_CONTENT
            }
            value == "auto" || value == null -> ViewGroup.LayoutParams.WRAP_CONTENT
            else -> dpToPx(context, toFloat(value, 0f)).toInt()
        }
    }

    fun toFloat(value: Any?, default: Float): Float = when (value) {
        is Double -> value.toFloat()
        is Float  -> value
        is Int    -> value.toFloat()
        is Long   -> value.toFloat()
        is String -> value.toFloatOrNull() ?: default
        else      -> default
    }

    fun toInt(value: Any?, default: Int): Int = when (value) {
        is Int    -> value
        is Double -> value.toInt()
        is Float  -> value.toInt()
        is Long   -> value.toInt()
        is String -> value.toIntOrNull() ?: default
        else      -> default
    }

    // -- GradientDrawable management ----------------------------------------------

    private fun ensureBackground(view: View): GradientDrawable {
        val existing = view.background
        if (existing is GradientDrawable) return existing
        val bg = GradientDrawable()
        view.background = bg
        return bg
    }

    // -- Flex enum parsing --------------------------------------------------------

    private fun parseFlexDirection(value: Any?) = when (value) {
        "row"            -> FlexDirection.ROW
        "row-reverse"    -> FlexDirection.ROW_REVERSE
        "column-reverse" -> FlexDirection.COLUMN_REVERSE
        else             -> FlexDirection.COLUMN
    }

    private fun parseFlexWrap(value: Any?) = when (value) {
        "wrap"         -> FlexWrap.WRAP
        "wrap-reverse" -> FlexWrap.WRAP_REVERSE
        else           -> FlexWrap.NO_WRAP
    }

    private fun parseAlignItems(value: Any?) = when (value) {
        "flex-start" -> AlignItems.FLEX_START
        "flex-end"   -> AlignItems.FLEX_END
        "center"     -> AlignItems.CENTER
        "baseline"   -> AlignItems.BASELINE
        else         -> AlignItems.STRETCH
    }

    private fun parseAlignContent(value: Any?) = when (value) {
        "flex-start"    -> AlignContent.FLEX_START
        "flex-end"      -> AlignContent.FLEX_END
        "center"        -> AlignContent.CENTER
        "space-between" -> AlignContent.SPACE_BETWEEN
        "space-around"  -> AlignContent.SPACE_AROUND
        else            -> AlignContent.STRETCH
    }

    private fun parseJustifyContent(value: Any?) = when (value) {
        "flex-end"      -> JustifyContent.FLEX_END
        "center"        -> JustifyContent.CENTER
        "space-between" -> JustifyContent.SPACE_BETWEEN
        "space-around"  -> JustifyContent.SPACE_AROUND
        "space-evenly"  -> JustifyContent.SPACE_EVENLY
        else            -> JustifyContent.FLEX_START
    }

    private fun parseAlignSelf(value: Any?) = when (value) {
        "flex-start" -> AlignSelf.FLEX_START
        "flex-end"   -> AlignSelf.FLEX_END
        "center"     -> AlignSelf.CENTER
        "baseline"   -> AlignSelf.BASELINE
        "stretch"    -> AlignSelf.STRETCH
        else         -> AlignSelf.AUTO
    }

    private val FLEX_LAYOUT_KEYS = setOf(
        "width", "height", "flex", "flexGrow", "flexShrink", "alignSelf", "order",
        "margin", "marginHorizontal", "marginVertical",
        "marginLeft", "marginRight", "marginTop", "marginBottom", "minWidth", "minHeight"
    )
}
