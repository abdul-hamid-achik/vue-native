import { defineComponent, h } from '@vue/runtime-core'

/**
 * Segmented control (tab strip) component.
 *
 * @example
 * <VSegmentedControl
 *   :values="['Day', 'Week', 'Month']"
 *   :selectedIndex="0"
 *   @change="onSegmentChange"
 * />
 */
export const VSegmentedControl = defineComponent({
  name: 'VSegmentedControl',
  props: {
    values: { type: Array as () => string[], required: true },
    selectedIndex: { type: Number, default: 0 },
    tintColor: { type: String, default: undefined },
    enabled: { type: Boolean, default: true },
    style: { type: Object, default: () => ({}) },
  },
  emits: ['change'],
  setup(props, { emit }) {
    return () =>
      h('VSegmentedControl', {
        values: props.values,
        selectedIndex: props.selectedIndex,
        tintColor: props.tintColor,
        enabled: props.enabled,
        style: props.style,
        onChange: (e: { selectedIndex: number; value: string }) => emit('change', e),
      })
  },
})
