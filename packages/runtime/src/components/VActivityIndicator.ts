import { defineComponent, h } from '@vue/runtime-core'

/**
 * VActivityIndicator — a loading spinner component.
 *
 * Maps to UIActivityIndicatorView on iOS.
 * Automatically hides when not animating (configurable via hidesWhenStopped).
 *
 * @example
 * ```vue
 * <VActivityIndicator :animating="isLoading" color="#007AFF" size="large" />
 * ```
 */
export const VActivityIndicator = defineComponent({
  name: 'VActivityIndicator',
  props: {
    animating: {
      type: Boolean,
      default: true,
    },
    color: String,
    size: {
      type: String,
      default: 'medium', // 'small' | 'medium' | 'large'
    },
    hidesWhenStopped: {
      type: Boolean,
      default: true,
    },
    style: Object,
  },
  setup(props) {
    return () =>
      h('VActivityIndicator', {
        animating: props.animating,
        color: props.color,
        size: props.size,
        hidesWhenStopped: props.hidesWhenStopped,
        style: props.style,
      })
  },
})
