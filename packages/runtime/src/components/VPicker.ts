import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

/**
 * Date/time picker component.
 *
 * Supports v-model like every other form component; the older
 * `:value` + `@change` pair keeps working.
 *
 * @example
 * <VPicker mode="date" v-model="date" />
 * <VPicker mode="date" :value="date" @change="date = $event.value" />
 */
export const VPicker = defineComponent({
  name: 'VPicker',
  props: {
    mode: { type: String as () => 'date' | 'time' | 'datetime', default: 'date' },
    modelValue: { type: Number, default: undefined }, // epoch milliseconds
    value: { type: Number, default: undefined }, // legacy alias of modelValue
    minimumDate: { type: Number, default: undefined },
    maximumDate: { type: Number, default: undefined },
    minuteInterval: { type: Number, default: 1 },
    style: { type: Object as PropType<ViewStyle>, default: () => ({}) },
  },
  emits: ['update:modelValue', 'change'],
  setup(props, { emit }) {
    return () =>
      h('VPicker', {
        mode: props.mode,
        value: props.modelValue ?? props.value,
        minimumDate: props.minimumDate,
        maximumDate: props.maximumDate,
        minuteInterval: props.minuteInterval,
        style: props.style,
        onChange: (e: { value: number }) => {
          emit('update:modelValue', e.value)
          emit('change', e)
        },
      })
  },
})
