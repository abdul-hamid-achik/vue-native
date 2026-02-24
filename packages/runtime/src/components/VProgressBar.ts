import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

/**
 * Horizontal progress indicator bar.
 *
 * @example
 * <VProgressBar :progress="0.75" progressTintColor="#007AFF" />
 */
export const VProgressBar = defineComponent({
  name: 'VProgressBar',
  props: {
    progress: { type: Number, default: 0 },
    progressTintColor: { type: String, default: undefined },
    trackTintColor: { type: String, default: undefined },
    animated: { type: Boolean, default: true },
    style: { type: Object as PropType<ViewStyle>, default: () => ({}) },
  },
  setup(props) {
    return () =>
      h('VProgressBar', {
        progress: props.progress,
        progressTintColor: props.progressTintColor,
        trackTintColor: props.trackTintColor,
        animated: props.animated,
        style: props.style,
      })
  },
})
