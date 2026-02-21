import { defineComponent, h } from '@vue/runtime-core'

/**
 * VButton — a pressable button component.
 *
 * Maps to a tappable UIView on iOS with built-in press animation.
 * Provides onPress and onLongPress event handling. The activeOpacity
 * controls how transparent the button becomes when pressed.
 *
 * @example
 * ```vue
 * <VButton
 *   :style="{ backgroundColor: '#007AFF', padding: 12, borderRadius: 8 }"
 *   :onPress="handleTap"
 *   :disabled="isLoading"
 * >
 *   <VText :style="{ color: '#fff', textAlign: 'center' }">Tap Me</VText>
 * </VButton>
 * ```
 */
export const VButton = defineComponent({
  name: 'VButton',
  props: {
    style: Object,
    disabled: {
      type: Boolean,
      default: false,
    },
    activeOpacity: {
      type: Number,
      default: 0.7,
    },
    onPress: Function,
    onLongPress: Function,
  },
  setup(props, { slots }) {
    return () =>
      h(
        'VButton',
        {
          ...props,
          onPress: props.disabled ? undefined : props.onPress,
          onLongPress: props.disabled ? undefined : props.onLongPress,
        },
        slots.default?.(),
      )
  },
})
