import { defineComponent, h } from '@vue/runtime-core'

/**
 * VText — component for displaying text content.
 *
 * Maps to UILabel on iOS. All text in Vue Native must be wrapped in a
 * VText component — raw text outside of VText will not be rendered.
 *
 * Supports text-specific styling such as fontSize, fontWeight, color,
 * lineHeight, letterSpacing, textAlign, and more.
 *
 * @example
 * ```vue
 * <VText :style="{ fontSize: 18, color: '#333' }" :numberOfLines="2">
 *   Hello, Vue Native!
 * </VText>
 * ```
 */
export const VText = defineComponent({
  name: 'VText',
  props: {
    style: Object,
    numberOfLines: Number,
    selectable: {
      type: Boolean,
      default: false,
    },
    accessibilityRole: String,
  },
  setup(props, { slots }) {
    return () => h('VText', { ...props }, slots.default?.())
  },
})
