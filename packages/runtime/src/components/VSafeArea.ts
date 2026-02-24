import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

export const VSafeArea = defineComponent({
  name: 'VSafeArea',
  props: {
    style: { type: Object as PropType<ViewStyle>, default: () => ({}) },
  },
  setup(props, { slots }) {
    return () => h('VSafeArea', { style: props.style }, slots.default?.())
  },
})
