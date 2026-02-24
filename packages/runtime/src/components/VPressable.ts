import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

/**
 * VPressable — a generic pressable container component.
 *
 * Like VButton but without any default styling or built-in text label.
 * Wraps any children in a touchable container with configurable press
 * feedback. Supports press, long press, pressIn, and pressOut events.
 *
 * On iOS this maps to a TouchableView (custom UIView) with opacity animation.
 * On Android this maps to a TouchableView (FlexboxLayout subclass).
 *
 * @example
 * ```vue
 * <VPressable
 *   :style="{ padding: 16 }"
 *   :onPress="handlePress"
 *   :onLongPress="handleLongPress"
 *   :activeOpacity="0.6"
 * >
 *   <VView :style="{ flexDirection: 'row', alignItems: 'center' }">
 *     <VImage :source="{ uri: icon }" :style="{ width: 24, height: 24 }" />
 *     <VText :style="{ marginLeft: 8 }">Press me</VText>
 *   </VView>
 * </VPressable>
 * ```
 */
export const VPressable = defineComponent({
  name: 'VPressable',
  props: {
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
    onPressIn: Function as PropType<() => void>,
    onPressOut: Function as PropType<() => void>,
    onLongPress: Function as PropType<() => void>,
    accessibilityLabel: String,
    accessibilityRole: String,
    accessibilityHint: String,
    accessibilityState: Object,
  },
  setup(props, { slots }) {
    return () =>
      h(
        'VPressable',
        {
          ...props,
          onPress: props.disabled ? undefined : props.onPress,
          onPressIn: props.disabled ? undefined : props.onPressIn,
          onPressOut: props.disabled ? undefined : props.onPressOut,
          onLongPress: props.disabled ? undefined : props.onLongPress,
        },
        slots.default?.(),
      )
  },
})
