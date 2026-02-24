import { defineComponent, h, ref, watch, onUnmounted } from '@vue/runtime-core'

export interface AlertButton {
  label: string
  style?: 'default' | 'cancel' | 'destructive'
}

/**
 * Native alert dialog component.
 *
 * @example
 * <VAlertDialog
 *   :visible="showAlert"
 *   title="Confirm"
 *   message="Are you sure?"
 *   :buttons="[{ label: 'Cancel', style: 'cancel' }, { label: 'Delete', style: 'destructive' }]"
 *   @confirm="onConfirm"
 *   @cancel="showAlert = false"
 * />
 */
export const VAlertDialog = defineComponent({
  name: 'VAlertDialog',
  props: {
    visible: { type: Boolean, default: false },
    title: { type: String, default: '' },
    message: { type: String, default: '' },
    buttons: { type: Array as () => AlertButton[], default: () => [] },
  },
  emits: ['confirm', 'cancel', 'action'],
  setup(props, { emit }) {
    // Debounce visible prop to prevent animation jank from rapid toggles
    const debouncedVisible = ref(props.visible)
    let visibleTimer: ReturnType<typeof setTimeout> | undefined

    watch(
      () => props.visible,
      (val) => {
        if (visibleTimer) clearTimeout(visibleTimer)
        visibleTimer = setTimeout(() => {
          debouncedVisible.value = val
        }, 50)
      },
    )

    onUnmounted(() => {
      if (visibleTimer) clearTimeout(visibleTimer)
    })

    return () =>
      h('VAlertDialog', {
        visible: debouncedVisible.value,
        title: props.title,
        message: props.message,
        buttons: props.buttons,
        onConfirm: (e: any) => emit('confirm', e),
        onCancel: () => emit('cancel'),
        onAction: (e: any) => emit('action', e),
      })
  },
})
