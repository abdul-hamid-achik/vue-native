import { defineComponent, h } from '@vue/runtime-core'

/**
 * VList — A virtualized list component backed by UITableView on iOS.
 *
 * Renders each item in `data` via the default `#item` slot.
 * Supports thousands of items with smooth scrolling and cell recycling.
 *
 * @example
 * <VList
 *   :data="items"
 *   :estimatedItemHeight="72"
 *   :style="{ flex: 1 }"
 *   @endReached="loadMore"
 * >
 *   <template #item="{ item, index }">
 *     <VView :style="rowStyle">
 *       <VText>{{ item.title }}</VText>
 *     </VView>
 *   </template>
 * </VList>
 */
export const VList = defineComponent({
  name: 'VList',

  props: {
    /** Array of data items to render */
    data: {
      type: Array as () => any[],
      required: true,
    },
    /** Extract a unique key from each item. Defaults to index as string. */
    keyExtractor: {
      type: Function as unknown as () => (item: any, index: number) => string,
      default: (_item: any, index: number) => String(index),
    },
    /** Estimated height per row in points. Used before layout runs. Default: 44 */
    estimatedItemHeight: {
      type: Number,
      default: 44,
    },
    /** Show vertical scroll indicator. Default: true */
    showsScrollIndicator: {
      type: Boolean,
      default: true,
    },
    /** Enable bounce at scroll boundaries. Default: true */
    bounces: {
      type: Boolean,
      default: true,
    },
    style: {
      type: Object,
      default: () => ({}),
    },
  },

  emits: ['scroll', 'endReached'],

  setup(props, { slots, emit }) {
    return () => {
      const items = props.data ?? []

      return h(
        'VList',
        {
          style: props.style,
          estimatedItemHeight: props.estimatedItemHeight,
          showsScrollIndicator: props.showsScrollIndicator,
          bounces: props.bounces,
          onScroll: (e: { x: number; y: number }) => emit('scroll', e),
          onEndReached: () => emit('endReached'),
        },
        items.map((item, index) =>
          h(
            'VView',
            {
              key: props.keyExtractor(item, index),
              style: { flexShrink: 0 },
            },
            slots.item?.({ item, index }) ?? []
          )
        )
      )
    }
  },
})
