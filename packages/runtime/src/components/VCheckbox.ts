import { defineComponent, h } from '@vue/runtime-core'

/**
 * VCheckbox — a boolean checkbox component with optional label.
 *
 * Maps to a custom checkbox view on iOS, CheckBox on Android.
 * Supports v-model for two-way binding.
 *
 * @example
 * ```vue
 * <VCheckbox v-model="accepted" label="I accept the terms" />
 * ```
 */
export const VCheckbox = defineComponent({
  name: 'VCheckbox',
  props: {
    modelValue: {
      type: Boolean,
      default: false,
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    label: {
      type: String,
      default: undefined,
    },
    checkColor: String,
    tintColor: String,
    style: Object,
    accessibilityLabel: String,
    accessibilityHint: String,
  },
  emits: ['update:modelValue', 'change'],
  setup(props, { emit }) {
    const onChange = (payload: any) => {
      const value = typeof payload === 'boolean' ? payload : !!(payload?.value ?? payload)
      emit('update:modelValue', value)
      emit('change', value)
    }

    return () =>
      h('VCheckbox', {
        value: props.modelValue,
        disabled: props.disabled,
        label: props.label,
        checkColor: props.checkColor,
        tintColor: props.tintColor,
        style: props.style,
        accessibilityLabel: props.accessibilityLabel,
        accessibilityHint: props.accessibilityHint,
        onChange,
      })
  },
})
