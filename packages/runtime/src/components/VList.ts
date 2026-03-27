import { defineComponent, h, type PropType, type VNode } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'
import { usePlatform } from '../composables/usePlatform'

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
      type: Array as PropType<unknown[]>,
      required: true,
    },
    /** Extract a unique key from each item. Defaults to index as string. */
    keyExtractor: {
      type: Function as PropType<(item: unknown, index: number) => string>,
      default: (_item: unknown, index: number) => String(index),
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
    const { isAndroid } = usePlatform()
    let lastScrollEmit = 0
    let endReachedFired = false

    const onScroll = (e: {
      x: number
      y: number
      contentWidth?: number
      layoutWidth?: number
    }) => {
      const now = Date.now()
      if (now - lastScrollEmit >= 16) {
        lastScrollEmit = now
        emit('scroll', e)
      }

      if (props.horizontal && !isAndroid) {
        const contentWidth = e.contentWidth ?? 0
        const layoutWidth = e.layoutWidth ?? 0
        const distanceFromEnd = contentWidth - layoutWidth - (e.x ?? 0)
        const threshold = layoutWidth * 0.2

        if (contentWidth > layoutWidth && distanceFromEnd < threshold && !endReachedFired) {
          endReachedFired = true
          emit('endReached')
        } else if (distanceFromEnd >= threshold) {
          endReachedFired = false
        }
      }
    }

    return () => {
      const items = props.data ?? []

      // Dev-only: warn about duplicate keys which break Vue reconciliation
      if (typeof __DEV__ !== 'undefined' && __DEV__ && items.length > 0) {
        const keys = new Set<string>()
        for (let index = 0; index < items.length; index++) {
          const key = props.keyExtractor(items[index], index)
          if (keys.has(key)) {
            console.warn(
              `[VueNative] VList: Duplicate key "${key}" at index ${index}. `
              + 'Each item must have a unique key for correct reconciliation.',
            )
            break // Only warn once
          }
          keys.add(key)
        }
      }

      const children: VNode[] = []

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

      if (props.horizontal && !isAndroid) {
        return h(
          'VScrollView',
          {
            style: props.style,
            horizontal: true,
            showsVerticalScrollIndicator: false,
            showsHorizontalScrollIndicator: props.showsScrollIndicator,
            bounces: props.bounces,
            onScroll,
          },
          [
            h(
              'VView',
              {
                style: {
                  flexDirection: 'row',
                  alignItems: 'stretch',
                },
              },
              children,
            ),
          ],
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
          onScroll,
          onEndReached: () => emit('endReached'),
        },
        children,
      )
    }
  },
})
