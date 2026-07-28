import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

declare const __PLATFORM__: string

export interface OutlineNode {
  id: string
  label: string
  children?: OutlineNode[]
}

export const VOutlineView = defineComponent({
  name: 'VOutlineView',
  props: {
    data: { type: Array as PropType<OutlineNode[]>, required: true },
    expandAll: { type: Boolean, default: false },
    selectionMode: {
      type: String as PropType<'single' | 'multiple' | 'none'>,
      default: 'single',
    },
    style: Object as PropType<ViewStyle>,
  },
  emits: ['select', 'expand', 'collapse'],
  setup(props, { emit }) {
    if (__DEV__ && typeof __PLATFORM__ !== 'undefined' && __PLATFORM__ !== 'macos') {
      console.warn(`[VueNative] <VOutlineView> is only supported on macOS; it renders nothing on ${__PLATFORM__}.`)
    }
    return () =>
      h('VOutlineView', {
        ...props,
        onSelect: (e: { id: string, label: string }) => emit('select', e),
        onExpand: (e: { id: string }) => emit('expand', e),
        onCollapse: (e: { id: string }) => emit('collapse', e),
      })
  },
})
