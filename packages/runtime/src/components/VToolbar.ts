import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

declare const __PLATFORM__: string

export interface ToolbarItem {
  id: string
  label: string
  icon?: string
}

export const VToolbar = defineComponent({
  name: 'VToolbar',
  props: {
    items: { type: Array as PropType<ToolbarItem[]>, required: true },
    displayMode: {
      type: String as PropType<'iconOnly' | 'labelOnly' | 'iconAndLabel'>,
      default: 'iconAndLabel',
    },
    showsBaselineSeparator: { type: Boolean, default: true },
    style: Object as PropType<ViewStyle>,
  },
  emits: ['itemClick'],
  setup(props, { emit }) {
    if (__DEV__ && typeof __PLATFORM__ !== 'undefined' && __PLATFORM__ !== 'macos') {
      console.warn(`[VueNative] <VToolbar> is only supported on macOS; it renders nothing on ${__PLATFORM__}.`)
    }
    return () =>
      h('VToolbar', {
        ...props,
        onItemClick: (e: { id: string }) => emit('itemClick', e),
      })
  },
})
