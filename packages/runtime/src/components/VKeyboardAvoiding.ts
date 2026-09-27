import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { StyleProp, ViewStyle } from '../types/styles'

/**
 * VKeyboardAvoiding — a container that adjusts its bottom padding when
 * the keyboard appears, preventing content from being obscured.
 *
 * Maps to a native UIView that observes keyboard notifications and
 * automatically adjusts the Yoga bottom padding.
 *
 * @example
 * ```vue
 * <VKeyboardAvoiding :style="{ flex: 1 }">
 *   <VInput placeholder="Type here..." />
 * </VKeyboardAvoiding>
 * ```
 */
export const VKeyboardAvoiding = defineComponent({
  name: 'VKeyboardAvoiding',
  props: {
    style: [Object, Array] as PropType<StyleProp<ViewStyle>>,
    testID: String,
  },
  setup(props, { slots }) {
    return () => h('VKeyboardAvoiding', { ...props }, slots.default?.())
  },
})
