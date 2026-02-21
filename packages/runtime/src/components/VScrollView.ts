import { defineComponent, h } from '@vue/runtime-core'

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
    contentContainerStyle: Object,
    style: Object,
  },
  emits: ['scroll'],
  setup(props, { slots, emit }) {
    const onScroll = (payload: any) => {
      emit('scroll', payload)
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
          style: props.style,
          onScroll,
        },
        slots.default?.(),
      )
  },
})
