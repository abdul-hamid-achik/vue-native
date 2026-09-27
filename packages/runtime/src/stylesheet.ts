/**
 * StyleSheet utility for Vue Native.
 *
 * Provides a createStyleSheet helper similar to React Native's StyleSheet.create().
 * In development mode, validates style property names against a known list.
 * In production, skips validation for performance.
 * The returned style object is frozen to prevent accidental mutation.
 */

/**
 * Complete list of valid style property names recognized by the native layout
 * engine (Yoga-based) and the UIKit rendering layer.
 */
export const validStyleProperties: ReadonlySet<string> = new Set([
  // Layout (Yoga / Flexbox)
  'flex',
  'flexDirection',
  'flexWrap',
  'flexGrow',
  'flexShrink',
  'flexBasis',
  'justifyContent',
  'alignItems',
  'alignSelf',
  'alignContent',
  'position',
  'top',
  'right',
  'bottom',
  'left',
  'width',
  'height',
  'minWidth',
  'minHeight',
  'maxWidth',
  'maxHeight',
  'margin',
  'marginTop',
  'marginRight',
  'marginBottom',
  'marginLeft',
  'marginStart',
  'marginEnd',
  'marginHorizontal',
  'marginVertical',
  'padding',
  'paddingTop',
  'paddingRight',
  'paddingBottom',
  'paddingLeft',
  'paddingStart',
  'paddingEnd',
  'paddingHorizontal',
  'paddingVertical',
  'gap',
  'rowGap',
  'columnGap',
  'direction',
  'display',
  'overflow',
  'zIndex',
  'aspectRatio',
  'elevation',

  // Visual
  'backgroundColor',
  'opacity',

  // Borders
  'borderWidth',
  'borderTopWidth',
  'borderRightWidth',
  'borderBottomWidth',
  'borderLeftWidth',
  'borderColor',
  'borderTopColor',
  'borderRightColor',
  'borderBottomColor',
  'borderLeftColor',
  'borderRadius',
  'borderTopLeftRadius',
  'borderTopRightRadius',
  'borderBottomLeftRadius',
  'borderBottomRightRadius',

  // Shadow
  'shadowColor',
  'shadowOffset',
  'shadowOpacity',
  'shadowRadius',

  // Text
  'color',
  'fontSize',
  'fontWeight',
  'fontFamily',
  'fontStyle',
  'lineHeight',
  'letterSpacing',
  'textAlign',
  'textDecorationLine',
  'textTransform',
  'includeFontPadding',

  // Image
  'resizeMode',
  'tintColor',

  // Transform
  'transform',

  // Accessibility
  'accessibilityLabel',
  'accessibilityRole',
  'accessibilityHint',
  'accessibilityState',
  'accessibilityValue',
  'accessible',
  'importantForAccessibility',
])

/**
 * Everything assignable to a component's `style` prop: a single style object, or
 * a (possibly nested) array of them where later entries win and falsy entries
 * are skipped.
 *
 * Re-exported from `./types/styles` so the historical
 * `import { type StyleProp } from '.../stylesheet'` keeps working; the
 * definition lives with the other style types because that is where components
 * already import from.
 */
export type { StyleProp, StyleArray } from './types/styles'

/**
 * Merge a `StyleProp` into a single flat object.
 *
 * Arrays are merged left to right so later entries override earlier ones, and
 * `false` / `null` / `undefined` entries are skipped — which is what makes
 * `:style="[styles.row, isActive && styles.active]"` work. Anything that is not
 * an object or an array flattens to `{}` rather than throwing, because this runs
 * inside the Vue render loop.
 *
 * This is the single implementation: the renderer's style-diffing path and any
 * component that needs to read its own `style` prop both call it. Components
 * that spread `props.style` directly instead produce `{ 0: …, 1: … }` index keys
 * when handed an array, which silently renders nothing.
 */
export function flattenStyle(style: unknown): Record<string, unknown> {
  if (style == null || style === false) return {}
  if (Array.isArray(style)) {
    const merged: Record<string, unknown> = {}
    for (const entry of style) {
      Object.assign(merged, flattenStyle(entry))
    }
    return merged
  }
  if (typeof style === 'object') {
    return style as Record<string, unknown>
  }
  return {}
}

/**
 * The result type of createStyleSheet — keys are the same as the input,
 * values are frozen style objects.
 */
export type StyleSheet<T extends Record<string, object>> = Readonly<{
  [K in keyof T]: Readonly<T[K]>
}>

import type { ViewStyle, TextStyle, ImageStyle } from './types/styles'

/** Union of all valid style types for createStyleSheet values */
export type AnyStyle = ViewStyle | TextStyle | ImageStyle

/**
 * The thinnest border the platform can render (mirrors React Native's
 * `StyleSheet.hairlineWidth`). Use for 1px-look dividers and borders.
 */
export const hairlineWidth = 0.5

/**
 * Create a style sheet object. This is the recommended way to define styles
 * for Vue Native components.
 *
 * In development mode, each style property is validated against the known
 * list of valid properties. Unknown properties will trigger a console warning.
 *
 * The returned object and each individual style are Object.freeze()'d to
 * prevent accidental mutation.
 *
 * @example
 * ```ts
 * const styles = createStyleSheet({
 *   container: {
 *     flex: 1,
 *     backgroundColor: '#ffffff',
 *     padding: 16,
 *   },
 *   title: {
 *     fontSize: 24,
 *     fontWeight: 'bold',
 *     color: '#333333',
 *   },
 * })
 * ```
 */
export function createStyleSheet<const T extends Record<string, object>>(
  styles: T,
): StyleSheet<T> {
  const isDev = typeof __DEV__ !== 'undefined' ? __DEV__ : true

  if (isDev) {
    for (const styleName in styles) {
      const styleObj = styles[styleName] as Record<string, unknown>
      for (const prop in styleObj) {
        if (!validStyleProperties.has(prop)) {
          console.warn(
            `[VueNative] Unknown style property "${prop}" in style "${styleName}". `
            + `This property will be ignored by the native renderer.`,
          )
        }
      }
    }
  }

  // Freeze each individual style object for immutability and perf
  const result = {} as { [K in keyof T]: Readonly<T[K]> }
  for (const key in styles) {
    const styleKey = key as keyof T
    result[styleKey] = Object.freeze({ ...styles[styleKey] }) as Readonly<T[typeof styleKey]>
  }

  // Freeze the container object itself
  return Object.freeze(result) as StyleSheet<T>
}
