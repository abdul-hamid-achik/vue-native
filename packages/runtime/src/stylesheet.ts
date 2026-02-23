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
  'marginHorizontal',
  'marginVertical',
  'padding',
  'paddingTop',
  'paddingRight',
  'paddingBottom',
  'paddingLeft',
  'paddingHorizontal',
  'paddingVertical',
  'gap',
  'rowGap',
  'columnGap',
  'display',
  'overflow',
  'zIndex',
  'aspectRatio',

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
  'borderStyle',

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
  'textDecorationStyle',
  'textDecorationColor',
  'textTransform',
  'includeFontPadding',

  // Image
  'resizeMode',
  'tintColor',

  // Transform
  'transform',
])

/**
 * A single style declaration — a flat object of style properties.
 */
export type StyleProp = Record<string, any>

/**
 * The result type of createStyleSheet — keys are the same as the input,
 * values are frozen style objects.
 */
export type StyleSheet<T extends Record<string, StyleProp>> = Readonly<{
  [K in keyof T]: Readonly<T[K]>
}>

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
export function createStyleSheet<T extends Record<string, StyleProp>>(
  styles: T,
): StyleSheet<T> {
  const isDev = typeof __DEV__ !== 'undefined' ? __DEV__ : true

  if (isDev) {
    for (const styleName in styles) {
      const styleObj = styles[styleName]
      for (const prop in styleObj) {
        if (!validStyleProperties.has(prop)) {
          console.warn(
            `[VueNative] Unknown style property "${prop}" in style "${styleName}". ` +
            `This property will be ignored by the native renderer.`
          )
        }
      }
    }
  }

  // Freeze each individual style object for immutability and perf
  const result = {} as any
  for (const key in styles) {
    result[key] = Object.freeze({ ...styles[key] })
  }

  // Freeze the container object itself
  return Object.freeze(result) as StyleSheet<T>
}
