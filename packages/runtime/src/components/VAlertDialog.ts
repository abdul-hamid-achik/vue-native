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
    confirmText: { type: String, default: '' },
    cancelText: { type: String, default: '' },
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

    return () => {
      // Build buttons from confirmText/cancelText when buttons array is empty
      let resolvedButtons = props.buttons
      if (resolvedButtons.length === 0 && (props.confirmText || props.cancelText)) {
        resolvedButtons = []
        if (props.cancelText) {
          resolvedButtons.push({ label: props.cancelText, style: 'cancel' })
        }
        if (props.confirmText) {
          resolvedButtons.push({ label: props.confirmText, style: 'default' })
        }
      }

      return h('VAlertDialog', {
        visible: debouncedVisible.value,
        title: props.title,
        message: props.message,
        buttons: resolvedButtons,
        onConfirm: (e: any) => emit('confirm', e),
        onCancel: () => emit('cancel'),
        onAction: (e: any) => emit('action', e),
      })
    }
  },
})
