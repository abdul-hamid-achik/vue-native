package com.vuenative.core

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.accessibility.AccessibilityNodeInfoCompat
import com.google.android.flexbox.AlignContent
import com.google.android.flexbox.AlignItems
import com.google.android.flexbox.AlignSelf
import com.google.android.flexbox.FlexDirection
import com.google.android.flexbox.FlexWrap
import com.google.android.flexbox.FlexboxLayout
import com.google.android.flexbox.JustifyContent
import kotlin.math.PI
import kotlin.math.roundToInt

/**
 * Converts JS style props to Android View properties.
 * Numbers are treated as dp (density-independent pixels).
 * Colors are hex strings like "#RRGGBB" or "#AARRGGBB".
 */
object StyleEngine {

    fun apply(key: String, value: Any?, view: View) {
        // Store internal props (prefixed with "__") as view tags
        if (key.startsWith("__")) {
            setInternalProp(key, value, view)
            return
        }
        val ctx = view.context
        when (key) {
            // --- Background & Visual ---
            "backgroundColor" -> {
                // A removed style is represented by null from the JS renderer.
                // Keep any border/radius drawable but reset its fill to transparent.
                val color = if (value == null) Color.TRANSPARENT else parseColor(value) ?: return
                ensureBackground(view).setColor(color)
                view.background = view.background
                view.invalidate()
            }
            "opacity" -> view.alpha = toFloat(value, 1f)
            "overflow" -> {
                val shouldClip = value == "hidden"
                (view as? ViewGroup)?.let { group ->
                    group.clipChildren = shouldClip
                    group.clipToPadding = shouldClip
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
                    "borderTopLeftRadius" -> {
                        radii[0] = px
                        radii[1] = px
                    }
                    "borderTopRightRadius" -> {
                        radii[2] = px
                        radii[3] = px
                    }
                    "borderBottomRightRadius" -> {
                        radii[4] = px
                        radii[5] = px
                    }
                    "borderBottomLeftRadius" -> {
                        radii[6] = px
                        radii[7] = px
                    }
                }
                bg.cornerRadii = radii
                view.background = view.background
            }
            "borderWidth" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                view.setTag(TAG_BORDER_WIDTH, px)
                val color = (view.getTag(TAG_BORDER_COLOR) as? Int) ?: Color.TRANSPARENT
                ensureBackground(view).setStroke(px, color)
                view.background = view.background
            }
            "borderColor" -> {
                val color = if (value == null) Color.TRANSPARENT else parseColor(value) ?: return
                view.setTag(TAG_BORDER_COLOR, color)
                val width = (view.getTag(TAG_BORDER_WIDTH) as? Int) ?: 1
                ensureBackground(view).setStroke(width, color)
                view.background = view.background
            }
            "borderBottomWidth" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                updatePaddingState(view) { state -> state.copy(borderBottom = px) }
            }
            "borderTopWidth" -> {
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                updatePaddingState(view) { state -> state.copy(borderTop = px) }
            }

            // --- Padding ---
            "padding" -> {
                val px = value?.let { dpToPx(ctx, toFloat(it, 0f)).toInt() }
                updatePaddingState(view) { state ->
                    state.copy(left = px, top = px, right = px, bottom = px)
                }
            }
            "paddingHorizontal" -> {
                val px = value?.let { dpToPx(ctx, toFloat(it, 0f)).toInt() }
                updatePaddingState(view) { state -> state.copy(left = px, right = px) }
            }
            "paddingVertical" -> {
                val px = value?.let { dpToPx(ctx, toFloat(it, 0f)).toInt() }
                updatePaddingState(view) { state -> state.copy(top = px, bottom = px) }
            }
            "paddingLeft", "paddingStart" -> {
                val px = value?.let { dpToPx(ctx, toFloat(it, 0f)).toInt() }
                updatePaddingState(view) { state -> state.copy(left = px) }
            }
            "paddingRight", "paddingEnd" -> {
                val px = value?.let { dpToPx(ctx, toFloat(it, 0f)).toInt() }
                updatePaddingState(view) { state -> state.copy(right = px) }
            }
            "paddingTop" -> {
                val px = value?.let { dpToPx(ctx, toFloat(it, 0f)).toInt() }
                updatePaddingState(view) { state -> state.copy(top = px) }
            }
            "paddingBottom" -> {
                val px = value?.let { dpToPx(ctx, toFloat(it, 0f)).toInt() }
                updatePaddingState(view) { state -> state.copy(bottom = px) }
            }

            // --- Margin (stored in FlexProps, applied when inserted into parent) ---
            "margin" -> updateFlexProps(view) { fp ->
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                fp.copy(marginLeft = px, marginTop = px, marginRight = px, marginBottom = px)
            }
            "marginHorizontal" -> updateFlexProps(view) { fp ->
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                fp.copy(marginLeft = px, marginRight = px)
            }
            "marginVertical" -> updateFlexProps(view) { fp ->
                val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                fp.copy(marginTop = px, marginBottom = px)
            }
            "marginLeft" -> updateFlexProps(view) { fp -> fp.copy(marginLeft = dpToPx(ctx, toFloat(value, 0f)).toInt()) }
            "marginRight" -> updateFlexProps(view) { fp -> fp.copy(marginRight = dpToPx(ctx, toFloat(value, 0f)).toInt()) }
            "marginTop" -> updateFlexProps(view) { fp -> fp.copy(marginTop = dpToPx(ctx, toFloat(value, 0f)).toInt()) }
            "marginBottom" -> updateFlexProps(view) { fp -> fp.copy(marginBottom = dpToPx(ctx, toFloat(value, 0f)).toInt()) }
            "marginStart" -> updateFlexProps(view) { fp -> fp.copy(marginStart = dpToPx(ctx, toFloat(value, 0f)).toInt()) }
            "marginEnd" -> updateFlexProps(view) { fp -> fp.copy(marginEnd = dpToPx(ctx, toFloat(value, 0f)).toInt()) }

            // --- Dimensions ---
            "width" -> {
                val pct = parsePercent(value)
                if (pct != null) {
                    updateFlexProps(view) { fp -> fp.copy(width = ViewGroup.LayoutParams.WRAP_CONTENT, widthPercent = pct) }
                } else {
                    updateFlexProps(view) { fp -> fp.copy(width = parseDimension(ctx, value), widthPercent = -1f) }
                }
            }
            "height" -> {
                val pct = parsePercent(value)
                if (pct != null) {
                    updateFlexProps(view) { fp -> fp.copy(height = ViewGroup.LayoutParams.WRAP_CONTENT, heightPercent = pct) }
                } else {
                    updateFlexProps(view) { fp -> fp.copy(height = parseDimension(ctx, value), heightPercent = -1f) }
                }
            }
            "minWidth" -> updateFlexProps(view) { fp -> fp.copy(minWidth = dpToPx(ctx, toFloat(value, 0f)).toInt()) }
            "minHeight" -> updateFlexProps(view) { fp -> fp.copy(minHeight = dpToPx(ctx, toFloat(value, 0f)).toInt()) }
            "maxWidth" -> updateFlexProps(view) { fp ->
                fp.copy(maxWidth = value?.let { dpToPx(ctx, toFloat(it, 0f)).toInt() } ?: Int.MAX_VALUE)
            }
            "maxHeight" -> updateFlexProps(view) { fp ->
                fp.copy(maxHeight = value?.let { dpToPx(ctx, toFloat(it, 0f)).toInt() } ?: Int.MAX_VALUE)
            }

            // --- Flex props (stored in FlexProps, applied when inserted) ---
            "flex" -> {
                updateFlexProps(view) { fp ->
                    if (value == null) {
                        // Reset the shorthand without discarding explicit width
                        // or height values that may still be supplied separately.
                        fp.copy(flexGrow = 0f, flexShrink = 1f, flexBasisPercent = -1f)
                    } else {
                        // `flex: n` uses a zero basis, but storing it as flex
                        // basis (rather than overwriting width/height) keeps
                        // conditional flex styles reversible.
                        fp.copy(
                            flexGrow = toFloat(value, 0f),
                            flexShrink = 1f,
                            flexBasisPercent = 0f,
                        )
                    }
                }
            }
            "flexGrow" -> updateFlexProps(view) { fp -> fp.copy(flexGrow = toFloat(value, 0f)) }
            "flexShrink" -> updateFlexProps(view) { fp -> fp.copy(flexShrink = toFloat(value, 1f)) }
            "flexBasis" -> {
                if (value == "auto" || value == null) {
                    updateFlexProps(view) { fp -> fp.copy(flexBasisPercent = -1f) }
                } else {
                    val str = value.toString()
                    if (str.endsWith("%")) {
                        val pct = str.dropLast(1).toFloatOrNull() ?: -1f
                        updateFlexProps(view) { fp -> fp.copy(flexBasisPercent = if (pct >= 0f) pct / 100f else -1f) }
                    } else {
                        val px = dpToPx(ctx, toFloat(value, 0f)).toInt()
                        updateFlexProps(view) { fp -> fp.copy(flexBasisPercent = -1f, width = px) }
                    }
                }
            }
            "alignSelf" -> updateFlexProps(view) { fp -> fp.copy(alignSelf = parseAlignSelf(value)) }
            "order" -> updateFlexProps(view) { fp -> fp.copy(order = toInt(value, 1)) }

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
                val px = value?.let { dpToPx(ctx, toFloat(it, 0f)).toInt() } ?: 0
                updateGap(view) { state -> state.copy(row = px, column = px) }
            }
            "rowGap" -> {
                val px = value?.let { dpToPx(ctx, toFloat(it, 0f)).toInt() } ?: 0
                updateGap(view) { state -> state.copy(row = px) }
            }
            "columnGap" -> {
                val px = value?.let { dpToPx(ctx, toFloat(it, 0f)).toInt() } ?: 0
                updateGap(view) { state -> state.copy(column = px) }
            }

            // --- Position (absolute) ---
            "position" -> {
                view.setTag(TAG_POSITION, value?.toString())
                if (value == "absolute") {
                    applyAbsolutePosition(view, ctx)
                }
            }
            "top" -> {
                view.setTag(TAG_POSITION_TOP, toFloat(value, Float.NaN))
                if (view.getTag(TAG_POSITION) == "absolute") applyAbsolutePosition(view, ctx)
            }
            "left" -> {
                view.setTag(TAG_POSITION_LEFT, toFloat(value, Float.NaN))
                if (view.getTag(TAG_POSITION) == "absolute") applyAbsolutePosition(view, ctx)
            }
            "right" -> {
                view.setTag(TAG_POSITION_RIGHT, toFloat(value, Float.NaN))
                if (view.getTag(TAG_POSITION) == "absolute") applyAbsolutePosition(view, ctx)
            }
            "bottom" -> {
                view.setTag(TAG_POSITION_BOTTOM, toFloat(value, Float.NaN))
                if (view.getTag(TAG_POSITION) == "absolute") applyAbsolutePosition(view, ctx)
            }

            // --- Elevation / Shadow ---
            "elevation" -> {
                view.elevation = dpToPx(ctx, toFloat(value, 0f))
            }
            "zIndex" -> {
                view.translationZ = dpToPx(ctx, toFloat(value, 0f))
            }
            "shadowColor" -> {
                val color = parseColor(value) ?: return
                view.setTag(TAG_SHADOW_COLOR, color)
                applyShadow(view, ctx)
            }
            "shadowOpacity" -> {
                view.setTag(TAG_SHADOW_OPACITY, toFloat(value, 1f))
                applyShadow(view, ctx)
            }
            "shadowRadius" -> {
                view.setTag(TAG_SHADOW_RADIUS, toFloat(value, 0f))
                applyShadow(view, ctx)
            }
            "shadowOffsetX" -> {
                view.setTag(TAG_SHADOW_OFFSET_X, toFloat(value, 0f))
                applyShadow(view, ctx)
            }
            "shadowOffsetY" -> {
                view.setTag(TAG_SHADOW_OFFSET_Y, toFloat(value, 0f))
                applyShadow(view, ctx)
            }
            "shadowOffset" -> {
                if (value is Map<*, *>) {
                    val w = toFloat(value["width"], 0f)
                    val h = toFloat(value["height"], 0f)
                    view.setTag(TAG_SHADOW_OFFSET_X, w)
                    view.setTag(TAG_SHADOW_OFFSET_Y, h)
                    applyShadow(view, ctx)
                }
            }

            // --- Transform ---
            "transform" -> {
                applyTransform(view, value, ctx)
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
                if (value == false || value == "false") {
                    view.visibility = View.INVISIBLE
                } else {
                    view.visibility = View.VISIBLE
                }
            }
            "hidden" -> {
                view.visibility = if (value == true || value == "true") View.INVISIBLE else View.VISIBLE
            }

            // --- Interaction ---
            "pointerEvents" -> {
                if (value == "none") {
                    if (view.getTag(TAG_POINTER_EVENTS_STATE) == null) {
                        view.setTag(
                            TAG_POINTER_EVENTS_STATE,
                            PointerEventsState(view.isClickable, view.isFocusable),
                        )
                    }
                    view.isClickable = false
                    view.isFocusable = false
                } else {
                    (view.getTag(TAG_POINTER_EVENTS_STATE) as? PointerEventsState)?.let { state ->
                        view.isClickable = state.clickable
                        view.isFocusable = state.focusable
                    }
                    view.setTag(TAG_POINTER_EVENTS_STATE, null)
                }
            }

            // --- Direction (RTL/LTR) ---
            "direction" -> {
                val dir = when (value?.toString()) {
                    "rtl" -> View.LAYOUT_DIRECTION_RTL
                    "ltr" -> View.LAYOUT_DIRECTION_LTR
                    else -> View.LAYOUT_DIRECTION_INHERIT
                }
                view.layoutDirection = dir
            }

            // --- Accessibility ---
            "accessibilityLabel" -> {
                view.contentDescription = value?.toString()
                view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            }
            "accessibilityHint" -> {
                // Android doesn't have a direct accessibilityHint API like iOS.
                // We use AccessibilityDelegate to provide the hint via tooltipText (API 28+)
                // or append it to contentDescription as a fallback.
                val hint = value?.toString() ?: return
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    view.tooltipText = hint
                }
                view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            }
            "accessibilityValue" -> {
                val stateDesc = value?.toString() ?: return
                ViewCompat.setStateDescription(view, stateDesc)
                view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            }
            "accessibilityRole" -> {
                val role = value?.toString() ?: return
                ViewCompat.setAccessibilityDelegate(view, object : androidx.core.view.AccessibilityDelegateCompat() {
                    override fun onInitializeAccessibilityNodeInfo(host: View, info: AccessibilityNodeInfoCompat) {
                        super.onInitializeAccessibilityNodeInfo(host, info)
                        when (role) {
                            "button" -> info.className = "android.widget.Button"
                            "link" -> info.addAction(AccessibilityNodeInfoCompat.AccessibilityActionCompat.ACTION_CLICK)
                            "header" -> info.isHeading = true
                            "image" -> info.className = "android.widget.ImageView"
                            "text" -> info.className = "android.widget.TextView"
                            "search" -> info.className = "android.widget.EditText"
                            "adjustable" -> info.className = "android.widget.SeekBar"
                            "tab" -> info.roleDescription = "tab"
                            "none" -> { /* no special role */ }
                        }
                    }
                })
                view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            }
            "accessibilityState" -> {
                val state = value as? Map<*, *>
                view.isEnabled = state?.get("disabled") != true
                view.isSelected = state?.get("selected") == true

                if (state?.containsKey("checked") == true) {
                    val stateDesc = if (state["checked"] == true) "checked" else "unchecked"
                    ViewCompat.setStateDescription(view, stateDesc)
                } else {
                    ViewCompat.setStateDescription(view, null)
                }
                view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            }
            "accessible" -> view.importantForAccessibility =
                if (value == true) {
                    View.IMPORTANT_FOR_ACCESSIBILITY_YES
                } else {
                    View.IMPORTANT_FOR_ACCESSIBILITY_NO
                }
            "importantForAccessibility" -> {
                view.importantForAccessibility = when (value) {
                    "auto" -> View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
                    "yes" -> View.IMPORTANT_FOR_ACCESSIBILITY_YES
                    "no" -> View.IMPORTANT_FOR_ACCESSIBILITY_NO
                    "no-hide-descendants" -> View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
                    else -> View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
                }
            }
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
                    if (value == "bold" || (value as? Number)?.toInt() ?: 0 >= 600) {
                        android.graphics.Typeface.BOLD
                    } else {
                        android.graphics.Typeface.NORMAL
                    }
                )
            }
            "fontStyle" -> {
                val current = tv.typeface ?: android.graphics.Typeface.DEFAULT
                tv.setTypeface(current,
                    if (value == "italic") {
                        android.graphics.Typeface.ITALIC
                    } else {
                        android.graphics.Typeface.NORMAL
                    }
                )
            }
            "textAlign" -> tv.textAlignment = when (value) {
                "center" -> View.TEXT_ALIGNMENT_CENTER
                "right" -> View.TEXT_ALIGNMENT_VIEW_END
                "left" -> View.TEXT_ALIGNMENT_VIEW_START
                else -> View.TEXT_ALIGNMENT_INHERIT
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
                    "underline" -> tv.paintFlags or android.graphics.Paint.UNDERLINE_TEXT_FLAG
                    "line-through" -> tv.paintFlags or android.graphics.Paint.STRIKE_THRU_TEXT_FLAG
                    "none" -> (tv.paintFlags and android.graphics.Paint.UNDERLINE_TEXT_FLAG.inv()
                                               and android.graphics.Paint.STRIKE_THRU_TEXT_FLAG.inv())
                    else -> tv.paintFlags
                }
            }
            "textTransform" -> {
                val t = tv.text?.toString() ?: ""
                tv.text = when (value) {
                    "uppercase" -> t.uppercase()
                    "lowercase" -> t.lowercase()
                    "capitalize" -> t.split(" ").joinToString(" ") { it.replaceFirstChar(Char::uppercase) }
                    else -> t
                }
            }
            "numberOfLines" -> {
                tv.maxLines = toInt(value, Int.MAX_VALUE).let { if (it == 0) Int.MAX_VALUE else it }
                tv.ellipsize = if (toInt(value, 0) > 0) android.text.TextUtils.TruncateAt.END else null
            }
        }
    }

    // -- View-state helpers -------------------------------------------------------

    /**
     * Android stores border insets and content padding in the same View padding
     * fields. Track the CSS values independently so repeated border updates do
     * not accumulate and removing a style restores the original native padding.
     */
    private data class PaddingState(
        val initialLeft: Int,
        val initialTop: Int,
        val initialRight: Int,
        val initialBottom: Int,
        val left: Int? = null,
        val top: Int? = null,
        val right: Int? = null,
        val bottom: Int? = null,
        val borderTop: Int = 0,
        val borderBottom: Int = 0,
    )

    private data class PointerEventsState(val clickable: Boolean, val focusable: Boolean)

    private data class GapState(val row: Int = 0, val column: Int = 0)

    private class GapDrawable(private val width: Int, private val height: Int) :
        ColorDrawable(Color.TRANSPARENT) {
        override fun getIntrinsicWidth(): Int = width
        override fun getIntrinsicHeight(): Int = height
    }

    private fun updatePaddingState(view: View, update: (PaddingState) -> PaddingState) {
        val current = view.getTag(TAG_PADDING_STATE) as? PaddingState ?: PaddingState(
            initialLeft = view.paddingLeft,
            initialTop = view.paddingTop,
            initialRight = view.paddingRight,
            initialBottom = view.paddingBottom,
        )
        val next = update(current)
        view.setTag(TAG_PADDING_STATE, next)
        view.setPadding(
            next.left ?: next.initialLeft,
            (next.top ?: next.initialTop) + next.borderTop,
            next.right ?: next.initialRight,
            (next.bottom ?: next.initialBottom) + next.borderBottom,
        )
    }

    private fun updateGap(view: View, update: (GapState) -> GapState) {
        val current = view.getTag(TAG_GAP) as? GapState ?: GapState()
        val next = update(current)
        view.setTag(TAG_GAP, next)

        (view as? FlexboxLayout)?.let { flexbox ->
            flexbox.setDividerDrawableHorizontal(GapDrawable(0, next.row))
            flexbox.setDividerDrawableVertical(GapDrawable(next.column, 0))
            flexbox.setShowDividerHorizontal(
                if (next.row > 0) FlexboxLayout.SHOW_DIVIDER_MIDDLE else FlexboxLayout.SHOW_DIVIDER_NONE,
            )
            flexbox.setShowDividerVertical(
                if (next.column > 0) FlexboxLayout.SHOW_DIVIDER_MIDDLE else FlexboxLayout.SHOW_DIVIDER_NONE,
            )
            flexbox.requestLayout()
        }
    }

    // -- Flex Props ---------------------------------------------------------------

    data class FlexProps(
        val width: Int = ViewGroup.LayoutParams.WRAP_CONTENT,
        val height: Int = ViewGroup.LayoutParams.WRAP_CONTENT,
        /** Percentage of parent width [0.0, 1.0]. -1f means not set (use `width` instead). */
        val widthPercent: Float = -1f,
        /** Percentage of parent height [0.0, 1.0]. -1f means not set (use `height` instead). */
        val heightPercent: Float = -1f,
        val marginLeft: Int = 0,
        val marginTop: Int = 0,
        val marginRight: Int = 0,
        val marginBottom: Int = 0,
        val marginStart: Int = Int.MIN_VALUE,
        val marginEnd: Int = Int.MIN_VALUE,
        val flexGrow: Float = 0f,
        val flexShrink: Float = 1f,
        val flexBasisPercent: Float = -1f,
        val alignSelf: Int = AlignSelf.AUTO,
        val order: Int = 1,
        val minWidth: Int = 0,
        val minHeight: Int = 0,
        val maxWidth: Int = Int.MAX_VALUE,
        val maxHeight: Int = Int.MAX_VALUE,
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
        val lp = flexLayoutParamsFromProps(fp)
        view.layoutParams = lp
        parent.requestLayout()
    }

    fun buildFlexLayoutParams(view: View): FlexboxLayout.LayoutParams {
        return flexLayoutParamsFromProps(getFlexProps(view))
    }

    fun applyPercentDimensions(parent: ViewGroup, availableWidth: Int, availableHeight: Int) {
        for (i in 0 until parent.childCount) {
            val child = parent.getChildAt(i)
            val fp = getFlexProps(child)
            if (fp.widthPercent < 0f && fp.heightPercent < 0f) continue

            val lp = child.layoutParams as? FlexboxLayout.LayoutParams ?: continue
            var changed = false
            if (fp.widthPercent >= 0f && availableWidth >= 0) {
                val width = (availableWidth * fp.widthPercent).roundToInt()
                if (lp.width != width) {
                    lp.width = width
                    changed = true
                }
            }
            if (fp.heightPercent >= 0f && availableHeight >= 0) {
                val height = (availableHeight * fp.heightPercent).roundToInt()
                if (lp.height != height) {
                    lp.height = height
                    changed = true
                }
            }
            if (changed) {
                child.layoutParams = lp
            }
        }
    }

    private fun flexLayoutParamsFromProps(fp: FlexProps): FlexboxLayout.LayoutParams {
        return FlexboxLayout.LayoutParams(fp.width, fp.height).apply {
            setMargins(fp.marginLeft, fp.marginTop, fp.marginRight, fp.marginBottom)
            if (fp.marginStart != Int.MIN_VALUE) marginStart = fp.marginStart
            if (fp.marginEnd != Int.MIN_VALUE) marginEnd = fp.marginEnd
            flexGrow = fp.flexGrow
            flexShrink = fp.flexShrink
            flexBasisPercent = fp.flexBasisPercent
            alignSelf = fp.alignSelf
            order = fp.order
            minWidth = fp.minWidth
            minHeight = fp.minHeight
            maxWidth = fp.maxWidth
            maxHeight = fp.maxHeight
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
        } catch (e: Exception) {
            null
        }
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
                // 100% maps to MATCH_PARENT; other percentages are handled via widthPercent/heightPercent
                // in the "width"/"height" cases above — this fallback covers minWidth/minHeight
                if (value == "100%") {
                    ViewGroup.LayoutParams.MATCH_PARENT
                } else {
                    ViewGroup.LayoutParams.WRAP_CONTENT
                }
            }
            value == "auto" || value == null -> ViewGroup.LayoutParams.WRAP_CONTENT
            else -> dpToPx(context, toFloat(value, 0f)).toInt()
        }
    }

    /** Returns the fraction [0.0, 1.0] if value is a percentage string (e.g. "50%"), else null. */
    private fun parsePercent(value: Any?): Float? {
        val str = value?.toString() ?: return null
        if (!str.endsWith("%")) return null
        val num = str.dropLast(1).toFloatOrNull() ?: return null
        return (num / 100f).coerceIn(0f, 1f)
    }

    fun toFloat(value: Any?, default: Float): Float = when (value) {
        is Double -> value.toFloat()
        is Float -> value
        is Int -> value.toFloat()
        is Long -> value.toFloat()
        is String -> value.toFloatOrNull() ?: default
        else -> default
    }

    fun toInt(value: Any?, default: Int): Int = when (value) {
        is Int -> value
        is Double -> value.toInt()
        is Float -> value.toInt()
        is Long -> value.toInt()
        is String -> value.toIntOrNull() ?: default
        else -> default
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
        "row" -> FlexDirection.ROW
        "row-reverse" -> FlexDirection.ROW_REVERSE
        "column-reverse" -> FlexDirection.COLUMN_REVERSE
        else -> FlexDirection.COLUMN
    }

    private fun parseFlexWrap(value: Any?) = when (value) {
        "wrap" -> FlexWrap.WRAP
        "wrap-reverse" -> FlexWrap.WRAP_REVERSE
        else -> FlexWrap.NOWRAP
    }

    private fun parseAlignItems(value: Any?) = when (value) {
        "flex-start" -> AlignItems.FLEX_START
        "flex-end" -> AlignItems.FLEX_END
        "center" -> AlignItems.CENTER
        "baseline" -> AlignItems.BASELINE
        else -> AlignItems.STRETCH
    }

    private fun parseAlignContent(value: Any?) = when (value) {
        "flex-start" -> AlignContent.FLEX_START
        "flex-end" -> AlignContent.FLEX_END
        "center" -> AlignContent.CENTER
        "space-between" -> AlignContent.SPACE_BETWEEN
        "space-around" -> AlignContent.SPACE_AROUND
        else -> AlignContent.STRETCH
    }

    private fun parseJustifyContent(value: Any?) = when (value) {
        "flex-end" -> JustifyContent.FLEX_END
        "center" -> JustifyContent.CENTER
        "space-between" -> JustifyContent.SPACE_BETWEEN
        "space-around" -> JustifyContent.SPACE_AROUND
        "space-evenly" -> JustifyContent.SPACE_EVENLY
        else -> JustifyContent.FLEX_START
    }

    private fun parseAlignSelf(value: Any?) = when (value) {
        "flex-start" -> AlignSelf.FLEX_START
        "flex-end" -> AlignSelf.FLEX_END
        "center" -> AlignSelf.CENTER
        "baseline" -> AlignSelf.BASELINE
        "stretch" -> AlignSelf.STRETCH
        else -> AlignSelf.AUTO
    }

    private val FLEX_LAYOUT_KEYS = setOf(
        "width", "height", "flex", "flexGrow", "flexShrink", "flexBasis", "alignSelf", "order",
        "margin", "marginHorizontal", "marginVertical",
        "marginLeft", "marginRight", "marginTop", "marginBottom",
        "marginStart", "marginEnd", "minWidth", "minHeight", "maxWidth", "maxHeight"
    )

    // -- Shadow helpers -----------------------------------------------------------

    private fun applyShadow(view: View, ctx: Context) {
        val radius = (view.getTag(TAG_SHADOW_RADIUS) as? Float) ?: 0f
        val opacity = (view.getTag(TAG_SHADOW_OPACITY) as? Float) ?: 1f
        val color = (view.getTag(TAG_SHADOW_COLOR) as? Int) ?: Color.BLACK

        // Use shadowRadius as elevation (Android's shadow model is elevation-based)
        val elevationPx = dpToPx(ctx, radius)
        view.elevation = elevationPx * opacity

        // Ensure the view has an outline provider so the shadow is visible
        if (view.outlineProvider == null || view.outlineProvider == ViewOutlineProvider.BACKGROUND) {
            view.outlineProvider = ViewOutlineProvider.BOUNDS
        }
        view.clipToOutline = false

        // On API 28+, set colored shadows
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // Apply opacity to shadow color's alpha channel
            val alpha = ((Color.alpha(color) * opacity).toInt()).coerceIn(0, 255)
            val shadowWithOpacity = Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
            view.outlineAmbientShadowColor = shadowWithOpacity
            view.outlineSpotShadowColor = shadowWithOpacity
        }
    }

    // -- Transform helpers --------------------------------------------------------

    private fun applyTransform(view: View, value: Any?, ctx: Context) {
        if (value == null || value == "none") {
            view.rotation = 0f
            view.scaleX = 1f
            view.scaleY = 1f
            view.translationX = 0f
            view.translationY = 0f
            return
        }

        val transforms = when (value) {
            is List<*> -> value.filterIsInstance<Map<*, *>>()
            else -> return
        }

        // Reset to defaults, then apply each transform in order
        var rotation = 0f
        var scaleX = 1f
        var scaleY = 1f
        var translateX = 0f
        var translateY = 0f

        val density = ctx.resources.displayMetrics.density

        for (dict in transforms) {
            dict["rotate"]?.let { v ->
                rotation += parseAngle(v.toString())
            }
            dict["scale"]?.let { v ->
                val s = toFloat(v, 1f)
                scaleX *= s
                scaleY *= s
            }
            dict["scaleX"]?.let { v ->
                scaleX *= toFloat(v, 1f)
            }
            dict["scaleY"]?.let { v ->
                scaleY *= toFloat(v, 1f)
            }
            dict["translateX"]?.let { v ->
                translateX += toFloat(v, 0f) * density
            }
            dict["translateY"]?.let { v ->
                translateY += toFloat(v, 0f) * density
            }
        }

        view.rotation = rotation
        view.scaleX = scaleX
        view.scaleY = scaleY
        view.translationX = translateX
        view.translationY = translateY
    }

    // -- Absolute positioning helpers ---------------------------------------------

    /**
     * Apply absolute positioning to a view using translationX/translationY.
     * The view is positioned relative to its parent using top/left/right/bottom offsets.
     * Must be called after the view is attached to a parent, or deferred via View.post().
     */
    private fun applyAbsolutePosition(view: View, ctx: Context) {
        // Defer until after layout so parent dimensions are available
        view.post {
            val parent = view.parent as? ViewGroup ?: return@post

            val topVal = view.getTag(TAG_POSITION_TOP) as? Float ?: Float.NaN
            val leftVal = view.getTag(TAG_POSITION_LEFT) as? Float ?: Float.NaN
            val rightVal = view.getTag(TAG_POSITION_RIGHT) as? Float ?: Float.NaN
            val bottomVal = view.getTag(TAG_POSITION_BOTTOM) as? Float ?: Float.NaN

            // Calculate translation relative to where the FlexboxLayout placed this view
            if (!topVal.isNaN()) {
                val targetY = dpToPx(ctx, topVal)
                view.translationY = targetY - view.top
            } else if (!bottomVal.isNaN()) {
                val targetY = parent.height - view.height - dpToPx(ctx, bottomVal)
                view.translationY = targetY - view.top
            }

            if (!leftVal.isNaN()) {
                val targetX = dpToPx(ctx, leftVal)
                view.translationX = targetX - view.left
            } else if (!rightVal.isNaN()) {
                val targetX = parent.width - view.width - dpToPx(ctx, rightVal)
                view.translationX = targetX - view.left
            }

            // Bring absolute-positioned views to the front
            view.bringToFront()
        }
    }

    /** Parse an angle string into degrees. Supports "45deg" and "1.5rad". */
    private fun parseAngle(str: String): Float {
        val s = str.trim().lowercase()
        if (s.endsWith("deg")) {
            return s.dropLast(3).toFloatOrNull() ?: 0f
        }
        if (s.endsWith("rad")) {
            val rad = s.dropLast(3).toFloatOrNull() ?: 0f
            return (rad * 180f / PI).toFloat()
        }
        // Fallback: treat as degrees if numeric
        return s.toFloatOrNull() ?: 0f
    }

    // --- Internal Props ---

    /** Store an internal prop (prefixed with "__") on a view via tags. */
    private fun setInternalProp(key: String, value: Any?, view: View) {
        @Suppress("UNCHECKED_CAST")
        val props = (view.getTag(TAG_INTERNAL_PROPS) as? MutableMap<String, Any?>) ?: mutableMapOf()
        if (value != null) props[key] = value else props.remove(key)
        view.setTag(TAG_INTERNAL_PROPS, props)
    }

    /** Retrieve an internal prop from a view. */
    fun getInternalProp(key: String, view: View): Any? {
        @Suppress("UNCHECKED_CAST")
        val props = view.getTag(TAG_INTERNAL_PROPS) as? Map<String, Any?>
        return props?.get(key)
    }
}
