import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

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
    /** Render list horizontally. Default: false */
    horizontal: {
      type: Boolean,
      default: false,
    },
    style: {
      type: Object as PropType<ViewStyle>,
      default: () => ({}),
    },
  },

  emits: ['scroll', 'endReached'],

  setup(props, { slots, emit }) {
    return () => {
      const items = props.data ?? []

      const children: any[] = []

      // Header slot
      if (slots.header) {
        children.push(
          h('VView', { key: '__header__', style: { flexShrink: 0 } }, slots.header()),
        )
      }

      // Empty state slot (shown when data is empty)
      if (items.length === 0 && slots.empty) {
        children.push(
          h('VView', { key: '__empty__', style: { flexShrink: 0 } }, slots.empty()),
        )
      }

      // Item slots
      for (let index = 0; index < items.length; index++) {
        const item = items[index]
        children.push(
          h(
            'VView',
            {
              key: props.keyExtractor(item, index),
              style: { flexShrink: 0 },
            },
            slots.item?.({ item, index }) ?? [],
          ),
        )
      }

      // Footer slot
      if (slots.footer) {
        children.push(
          h('VView', { key: '__footer__', style: { flexShrink: 0 } }, slots.footer()),
        )
      }

      return h(
        'VList',
        {
          style: props.style,
          estimatedItemHeight: props.estimatedItemHeight,
          showsScrollIndicator: props.showsScrollIndicator,
          bounces: props.bounces,
          horizontal: props.horizontal,
          onScroll: (e: { x: number, y: number }) => emit('scroll', e),
          onEndReached: () => emit('endReached'),
        },
        children,
      )
    }
  },
})
