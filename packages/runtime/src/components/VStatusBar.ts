import { defineComponent, h } from '@vue/runtime-core'

export type StatusBarStyle = 'default' | 'light-content' | 'dark-content'

/**
 * Control the system status bar appearance.
 *
 * @example
 * <VStatusBar bar-style="light-content" />
 */
export const VStatusBar = defineComponent({
  name: 'VStatusBar',
  props: {
    barStyle: { type: String as () => StatusBarStyle, default: 'default' },
    hidden: { type: Boolean, default: false },
    animated: { type: Boolean, default: true },
  },
  setup(props) {
    return () =>
      h('VStatusBar', {
        barStyle: props.barStyle,
        hidden: props.hidden,
        animated: props.animated,
      })
  },
})
