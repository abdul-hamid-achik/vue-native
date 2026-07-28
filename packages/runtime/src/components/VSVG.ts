import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

/**
 * Source for a `VSVG` image. Provide exactly one of:
 * - `svg` — inline SVG markup string.
 * - `asset` — a bundled SVG asset name (iOS/macOS main bundle, Android `assets/`).
 * - `uri` — a remote SVG URL.
 */
export interface SVGSource {
  /** Inline SVG markup. */
  svg?: string
  /** Bundled SVG asset name. */
  asset?: string
  /** Remote SVG URL. */
  uri?: string
}

/**
 * VSVG — renders Scalable Vector Graphics natively.
 *
 * Maps to SVGKit-backed views on iOS/macOS and AndroidSVG on Android. Accepts
 * inline SVG markup, a bundled asset, or a remote URI, and scales to the size
 * given in `style` (vector-crisp at any resolution).
 *
 * @example
 * ```vue
 * <!-- inline markup -->
 * <VSVG :source="{ svg: '<svg viewBox=\'0 0 24 24\'>...</svg>' }"
 *       :style="{ width: 24, height: 24 }" />
 *
 * <!-- bundled asset -->
 * <VSVG :source="{ asset: 'icons/logo' }" :style="{ width: 120, height: 40 }" />
 * ```
 */
export const VSVG = defineComponent({
  name: 'VSVG',

  props: {
    source: Object as PropType<SVGSource>,
    /** Optional tint applied to the rendered SVG (hex color string). */
    tintColor: String,
    style: Object as PropType<ViewStyle>,
    testID: String,
    accessibilityLabel: String,
    accessibilityRole: {
      type: String,
      default: 'image',
    },
    accessibilityHint: String,
    accessibilityState: Object,
  },

  emits: ['load', 'error'],

  setup(props, { emit }) {
    return () =>
      h('VSVG', {
        source: props.source,
        tintColor: props.tintColor,
        style: props.style,
        testID: props.testID,
        accessibilityLabel: props.accessibilityLabel,
        accessibilityRole: props.accessibilityRole,
        accessibilityHint: props.accessibilityHint,
        accessibilityState: props.accessibilityState,
        onLoad: () => emit('load'),
        onError: () => emit('error'),
      })
  },
})
