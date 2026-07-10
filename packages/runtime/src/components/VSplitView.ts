import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

export const VSplitView = defineComponent({
  name: 'VSplitView',
  props: {
    direction: {
      type: String as PropType<'horizontal' | 'vertical'>,
      default: 'horizontal',
    },
    dividerStyle: {
      type: String as PropType<'thin' | 'thick' | 'paneSplitter'>,
      default: 'thin',
    },
    dividerColor: String,
    dividerPosition: Number,
    style: Object as PropType<ViewStyle>,
  },
  emits: ['resize'],
  setup(props, { emit, slots }) {
    return () =>
      h('VSplitView', {
        ...props,
        onResize: (e: { positions: number[] }) => emit('resize', e),
      }, slots.default?.())
  },
})
