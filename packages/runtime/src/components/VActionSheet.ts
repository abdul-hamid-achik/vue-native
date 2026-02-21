import { defineComponent, h } from '@vue/runtime-core'

export interface ActionSheetAction {
  label: string
  style?: 'default' | 'cancel' | 'destructive'
}

/**
 * Native action sheet (bottom sheet with multiple actions).
 *
 * @example
 * <VActionSheet
 *   :visible="showSheet"
 *   title="Choose an option"
 *   :actions="[
 *     { label: 'Edit' },
 *     { label: 'Delete', style: 'destructive' },
 *     { label: 'Cancel', style: 'cancel' },
 *   ]"
 *   @action="onAction"
 *   @cancel="showSheet = false"
 * />
 */
export const VActionSheet = defineComponent({
  name: 'VActionSheet',
  props: {
    visible: { type: Boolean, default: false },
    title: { type: String, default: undefined },
    message: { type: String, default: undefined },
    actions: { type: Array as () => ActionSheetAction[], default: () => [] },
  },
  emits: ['action', 'cancel'],
  setup(props, { emit }) {
    return () =>
      h('VActionSheet', {
        visible: props.visible,
        title: props.title,
        message: props.message,
        actions: props.actions,
        onAction: (e: { label: string }) => emit('action', e),
        onCancel: () => emit('cancel'),
      })
  },
})
