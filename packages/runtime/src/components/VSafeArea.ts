import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { StyleProp, ViewStyle } from '../types/styles'

export const VSafeArea = defineComponent({
  name: 'VSafeArea',
  props: {
    style: { type: [Object, Array] as PropType<StyleProp<ViewStyle>>, default: () => ({}) },
  },
  setup(props, { slots }) {
    return () => h('VSafeArea', { style: props.style }, slots.default?.())
  },
})
