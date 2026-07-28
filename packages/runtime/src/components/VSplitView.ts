import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

declare const __PLATFORM__: string

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
    if (__DEV__ && typeof __PLATFORM__ !== 'undefined' && __PLATFORM__ !== 'macos') {
      console.warn(`[VueNative] <VSplitView> is only supported on macOS; it renders nothing on ${__PLATFORM__}.`)
    }
    return () =>
      h('VSplitView', {
        ...props,
        onResize: (e: { positions: number[] }) => emit('resize', e),
      }, slots.default?.())
  },
})
