import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

function getSliderValue(payload: unknown): number | null {
  const value = typeof payload === 'object' && payload !== null && 'value' in payload
    ? (payload as { value?: unknown }).value
    : payload

  return typeof value === 'number' && Number.isFinite(value) ? value : null
}

export const VSlider = defineComponent({
  name: 'VSlider',
  props: {
    modelValue: { type: Number, default: 0 },
    min: { type: Number, default: 0 },
    max: { type: Number, default: 1 },
    style: { type: Object as PropType<ViewStyle>, default: () => ({}) },
    accessibilityLabel: String,
    accessibilityRole: String,
    accessibilityHint: String,
    accessibilityState: Object,
  },
  emits: ['update:modelValue', 'change'],
  setup(props, { emit }) {
    return () => h('VSlider', {
      style: props.style,
      value: props.modelValue,
      minimumValue: props.min,
      maximumValue: props.max,
      accessibilityLabel: props.accessibilityLabel,
      accessibilityRole: props.accessibilityRole,
      accessibilityHint: props.accessibilityHint,
      accessibilityState: props.accessibilityState,
      onChange: (payload: unknown) => {
        const value = getSliderValue(payload)
        if (value === null) return

        emit('update:modelValue', value)
        emit('change', value)
      },
    })
  },
})
