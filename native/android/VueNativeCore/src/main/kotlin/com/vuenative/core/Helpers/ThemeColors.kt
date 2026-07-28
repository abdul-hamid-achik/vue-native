package com.vuenative.core

import android.content.Context
import android.content.res.Configuration
import android.util.TypedValue
import androidx.core.content.ContextCompat

/**
 * Resolves theme-adaptive colors so text stays legible in both light and dark
 * mode. Prefers the Material `colorOnSurface` attribute when the host theme
 * provides it, and falls back to a night-mode-aware default otherwise.
 *
 * This replaces the previous hard-coded `Color.BLACK` text color, which was
 * invisible on dark surfaces.
 */
object ThemeColors {

    private const val LIGHT_DEFAULT = 0xFF000000.toInt() // near-black
    private const val DARK_DEFAULT = 0xFFFFFFFF.toInt() // near-white
    private const val ACCENT_DEFAULT = 0xFF6200EE.toInt() // Material purple fallback

    /** A text color that contrasts with the current theme's surface. */
    fun defaultTextColor(context: Context): Int =
        resolveAttr(context, com.google.android.material.R.attr.colorOnSurface)
            ?: if (isNightMode(context)) DARK_DEFAULT else LIGHT_DEFAULT

    /** The theme's primary/accent color, used for focus affordances. */
    fun accentColor(context: Context): Int =
        resolveAttr(context, com.google.android.material.R.attr.colorPrimary)
            ?: resolveAttr(context, androidx.appcompat.R.attr.colorAccent)
            ?: ACCENT_DEFAULT

    private fun isNightMode(context: Context): Boolean {
        val mask = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return mask == Configuration.UI_MODE_NIGHT_YES
    }

    private fun resolveAttr(context: Context, attr: Int): Int? {
        return try {
            val value = TypedValue()
            if (!context.theme.resolveAttribute(attr, value, true)) return null
            // resolveAttribute may yield a raw color or a resource reference.
            if (value.type >= TypedValue.TYPE_FIRST_COLOR_INT && value.type <= TypedValue.TYPE_LAST_COLOR_INT) {
                value.data
            } else if (value.resourceId != 0) {
                ContextCompat.getColor(context, value.resourceId)
            } else {
                value.data
            }
        } catch (e: Exception) {
            null
        }
    }
}
