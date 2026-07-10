import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { TextStyle, ViewStyle } from '../types/styles'
import { VText } from './VText'

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
    /** Convenience label rendered as VText when no default slot is provided. */
    title: String,
    /** Text styling for the title shorthand. */
    titleStyle: Object as PropType<TextStyle>,
    style: Object as PropType<ViewStyle>,
    disabled: {
      type: Boolean,
      default: false,
    },
    activeOpacity: {
      type: Number,
      default: 0.7,
    },
    onPress: Function as PropType<() => void>,
    onLongPress: Function as PropType<() => void>,
    accessibilityLabel: String,
    accessibilityRole: String,
    accessibilityHint: String,
    accessibilityState: Object,
  },
  setup(props, { slots }) {
    return () => {
      const slotContent = slots.default?.()
      const content = slotContent?.length
        ? slotContent
        : props.title !== undefined
          ? [h(VText, { style: props.titleStyle }, () => props.title)]
          : []

      return h(
        'VButton',
        {
          style: props.style,
          disabled: props.disabled,
          activeOpacity: props.activeOpacity,
          onPress: props.disabled ? undefined : props.onPress,
          onLongPress: props.disabled ? undefined : props.onLongPress,
          accessibilityLabel: props.accessibilityLabel,
          accessibilityRole: props.accessibilityRole,
          accessibilityHint: props.accessibilityHint,
          accessibilityState: props.accessibilityState,
        },
        content,
      )
    }
  },
})
