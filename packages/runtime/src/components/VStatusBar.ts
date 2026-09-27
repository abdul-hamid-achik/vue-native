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
    /**
     * Status bar background colour. **Android only** — on iOS the status bar is a
     * transparent overlay tinted by the view behind it, and macOS has no status
     * bar, so both ignore this prop.
     *
     * `VStatusBarFactory.kt` already implemented this, but the render function
     * below lists its forwarded keys explicitly, so the value never reached the
     * bridge and the native branch was unreachable dead code.
     */
    backgroundColor: { type: String, default: undefined },
  },
  setup(props) {
    return () =>
      h('VStatusBar', {
        barStyle: props.barStyle,
        hidden: props.hidden,
        animated: props.animated,
        backgroundColor: props.backgroundColor,
      })
  },
})
