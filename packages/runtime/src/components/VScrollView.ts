import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

/**
 * VScrollView — a scrollable container component.
 *
 * Maps to UIScrollView on iOS. Children are automatically added to an
 * inner content view so Yoga can compute their natural size unconstrained
 * by the scroll view's visible bounds.
 *
 * @example
 * ```vue
 * <VScrollView :style="{ flex: 1 }">
 *   <VView v-for="item in items" :key="item.id" :style="styles.row">
 *     <VText>{{ item.title }}</VText>
 *   </VView>
 * </VScrollView>
 * ```
 */
export const VScrollView = defineComponent({
  name: 'VScrollView',
  props: {
    horizontal: {
      type: Boolean,
      default: false,
    },
    showsVerticalScrollIndicator: {
      type: Boolean,
      default: true,
    },
    showsHorizontalScrollIndicator: {
      type: Boolean,
      default: false,
    },
    scrollEnabled: {
      type: Boolean,
      default: true,
    },
    bounces: {
      type: Boolean,
      default: true,
    },
    pagingEnabled: {
      type: Boolean,
      default: false,
    },
    contentContainerStyle: Object as PropType<ViewStyle>,
    /** Minimum interval in ms between scroll event emissions. Default: 16 (~60fps) */
    scrollEventThrottle: {
      type: Number,
      default: 16,
    },
    /** Whether the pull-to-refresh indicator is active */
    refreshing: {
      type: Boolean,
      default: false,
    },
    style: Object as PropType<ViewStyle>,
    accessibilityLabel: String,
    accessibilityRole: String,
    accessibilityHint: String,
    accessibilityState: Object,
  },
  emits: ['scroll', 'refresh'],
  setup(props, { slots, emit }) {
    let lastScrollEmit = 0

    const onScroll = (payload: any) => {
      const now = Date.now()
      if (now - lastScrollEmit >= props.scrollEventThrottle) {
        lastScrollEmit = now
        emit('scroll', payload)
      }
    }
    const onRefresh = () => {
      emit('refresh')
    }

    return () =>
      h(
        'VScrollView',
        {
          horizontal: props.horizontal,
          showsVerticalScrollIndicator: props.showsVerticalScrollIndicator,
          showsHorizontalScrollIndicator: props.showsHorizontalScrollIndicator,
          scrollEnabled: props.scrollEnabled,
          bounces: props.bounces,
          pagingEnabled: props.pagingEnabled,
          contentContainerStyle: props.contentContainerStyle,
          refreshing: props.refreshing,
          style: props.style,
          accessibilityLabel: props.accessibilityLabel,
          accessibilityRole: props.accessibilityRole,
          accessibilityHint: props.accessibilityHint,
          accessibilityState: props.accessibilityState,
          onScroll,
          onRefresh,
        },
        slots.default?.(),
      )
  },
})
