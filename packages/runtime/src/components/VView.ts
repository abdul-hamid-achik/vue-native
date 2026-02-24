import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

/**
 * VView — the fundamental container component in Vue Native.
 *
 * Maps to UIView on iOS. Supports flexbox layout via the native Yoga
 * layout engine. This is the equivalent of a <div> in web development.
 *
 * @example
 * ```vue
 * <VView :style="{ flex: 1, padding: 16, backgroundColor: '#fff' }">
 *   <VText>Hello World</VText>
 * </VView>
 * ```
 */
export const VView = defineComponent({
  name: 'VView',
  props: {
    style: Object as PropType<ViewStyle>,
    testID: String,
    accessibilityLabel: String,
    accessibilityRole: String,
    accessibilityHint: String,
    accessibilityState: Object,
  },
  setup(props, { slots }) {
    return () => h('VView', { ...props }, slots.default?.())
  },
})
