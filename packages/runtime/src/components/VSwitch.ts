import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

/**
 * VSwitch — a boolean toggle switch component.
 *
 * Maps to UISwitch on iOS. Supports v-model for two-way binding.
 *
 * @example
 * ```vue
 * <VSwitch v-model="notificationsEnabled" :onTintColor="'#34C759'" />
 * ```
 */
export const VSwitch = defineComponent({
  name: 'VSwitch',
  props: {
    modelValue: {
      type: Boolean,
      default: false,
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    onTintColor: String,
    thumbTintColor: String,
    style: Object as PropType<ViewStyle>,
    accessibilityLabel: String,
    accessibilityRole: String,
    accessibilityHint: String,
    accessibilityState: Object,
  },
  emits: ['update:modelValue', 'change'],
  setup(props, { emit }) {
    const onChange = (payload: any) => {
      const value = typeof payload === 'boolean' ? payload : !!(payload?.value ?? payload)
      emit('update:modelValue', value)
      emit('change', value)
    }

    return () =>
      h('VSwitch', {
        value: props.modelValue,
        disabled: props.disabled,
        onTintColor: props.onTintColor,
        thumbTintColor: props.thumbTintColor,
        style: props.style,
        accessibilityLabel: props.accessibilityLabel,
        accessibilityRole: props.accessibilityRole,
        accessibilityHint: props.accessibilityHint,
        accessibilityState: props.accessibilityState,
        onChange,
      })
  },
})
