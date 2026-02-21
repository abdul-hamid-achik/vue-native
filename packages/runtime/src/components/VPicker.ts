import { defineComponent, h } from '@vue/runtime-core'

/**
 * Date/time picker component.
 *
 * @example
 * <VPicker mode="date" :value="date" @change="date = $event.value" />
 */
export const VPicker = defineComponent({
  name: 'VPicker',
  props: {
    mode: { type: String as () => 'date' | 'time' | 'datetime', default: 'date' },
    value: { type: Number, default: undefined }, // epoch milliseconds
    minimumDate: { type: Number, default: undefined },
    maximumDate: { type: Number, default: undefined },
    minuteInterval: { type: Number, default: 1 },
    style: { type: Object, default: () => ({}) },
  },
  emits: ['change'],
  setup(props, { emit }) {
    return () =>
      h('VPicker', {
        mode: props.mode,
        value: props.value,
        minimumDate: props.minimumDate,
        maximumDate: props.maximumDate,
        minuteInterval: props.minuteInterval,
        style: props.style,
        onChange: (e: { value: number }) => emit('change', e),
      })
  },
})
