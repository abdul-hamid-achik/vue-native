import { defineComponent, h } from '@vue/runtime-core'

export const VSlider = defineComponent({
  name: 'VSlider',
  props: {
    modelValue: { type: Number, default: 0 },
    min: { type: Number, default: 0 },
    max: { type: Number, default: 1 },
    style: { type: Object, default: () => ({}) },
  },
  emits: ['update:modelValue', 'change'],
  setup(props, { emit }) {
    return () => h('VSlider', {
      style: props.style,
      value: props.modelValue,
      minimumValue: props.min,
      maximumValue: props.max,
      onChange: (val: number) => {
        emit('update:modelValue', val)
        emit('change', val)
      },
    })
  },
})
