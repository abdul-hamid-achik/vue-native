import { defineComponent, h, type PropType } from '@vue/runtime-core'

export interface RadioOption {
  label: string
  value: string
}

function extractRadioValue(payload: unknown): string | undefined {
  const nextValue = typeof payload === 'object' && payload !== null && 'value' in payload
    ? (payload as { value?: unknown }).value
    : payload

  return typeof nextValue === 'string' ? nextValue : undefined
}

/**
 * VRadio — a radio button group component.
 *
 * Maps to a custom UIStackView with radio circles on iOS,
 * RadioGroup + RadioButton on Android.
 *
 * @example
 * ```vue
 * <VRadio
 *   v-model="size"
 *   :options="[
 *     { label: 'Small', value: 'sm' },
 *     { label: 'Medium', value: 'md' },
 *     { label: 'Large', value: 'lg' },
 *   ]"
 * />
 * ```
 */
export const VRadio = defineComponent({
  name: 'VRadio',
  props: {
    modelValue: {
      type: String,
      default: undefined,
    },
    options: {
      type: Array as PropType<RadioOption[]>,
      required: true,
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    tintColor: String,
    style: Object,
    accessibilityLabel: String,
  },
  emits: ['update:modelValue', 'change'],
  setup(props, { emit }) {
    const onChange = (payload: unknown) => {
      const value = extractRadioValue(payload)
      emit('update:modelValue', value)
      emit('change', value)
    }

    return () =>
      h('VRadio', {
        selectedValue: props.modelValue,
        options: props.options,
        disabled: props.disabled,
        tintColor: props.tintColor,
        style: props.style,
        accessibilityLabel: props.accessibilityLabel,
        onChange,
      })
  },
})
