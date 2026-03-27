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
    const onChange = (payload: unknown) => {
      const nextValue = typeof payload === 'object' && payload !== null && 'value' in payload
        ? (payload as { value?: unknown }).value
        : payload
      const value = typeof nextValue === 'boolean' ? nextValue : Boolean(nextValue)
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
