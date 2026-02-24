import { defineComponent, h, type PropType } from '@vue/runtime-core'

export interface DropdownOption {
  label: string
  value: string
}

/**
 * VDropdown — a dropdown/picker selection component.
 *
 * Maps to UIMenu (iOS 14+) or UIPickerView on iOS, Spinner on Android.
 *
 * @example
 * ```vue
 * <VDropdown
 *   v-model="country"
 *   placeholder="Select country"
 *   :options="[
 *     { label: 'United States', value: 'us' },
 *     { label: 'Canada', value: 'ca' },
 *     { label: 'Mexico', value: 'mx' },
 *   ]"
 * />
 * ```
 */
export const VDropdown = defineComponent({
  name: 'VDropdown',
  props: {
    modelValue: {
      type: String,
      default: undefined,
    },
    options: {
      type: Array as PropType<DropdownOption[]>,
      required: true,
    },
    placeholder: {
      type: String,
      default: 'Select...',
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
    const onChange = (payload: any) => {
      const value = payload?.value ?? payload
      emit('update:modelValue', value)
      emit('change', value)
    }

    return () =>
      h('VDropdown', {
        selectedValue: props.modelValue,
        options: props.options,
        placeholder: props.placeholder,
        disabled: props.disabled,
        tintColor: props.tintColor,
        style: props.style,
        accessibilityLabel: props.accessibilityLabel,
        onChange,
      })
  },
})
