import { defineComponent, h } from '@vue/runtime-core'

export const VSafeArea = defineComponent({
  name: 'VSafeArea',
  props: {
    style: { type: Object, default: () => ({}) },
  },
  setup(props, { slots }) {
    return () => h('VSafeArea', { style: props.style }, slots.default?.())
  },
})
