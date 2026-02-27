import { defineComponent, h, ref, computed, type PropType, type VNode } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

/**
 * Information provided to the renderItem function.
 */
export interface FlatListRenderItemInfo<T = any> {
  item: T
  index: number
}

/**
 * Scroll event payload from the native scroll view.
 */
interface ScrollEvent {
  x: number
  y: number
  contentWidth?: number
  contentHeight?: number
  layoutWidth?: number
  layoutHeight?: number
}

/**
 * VFlatList — A high-performance virtualized list for large datasets.
 *
 * Unlike VList (which renders all items), VFlatList only creates native views
 * for items currently visible on screen plus a configurable buffer. This reduces
 * memory usage from O(n) to O(visible) — critical for lists with 1000+ items.
 *
 * Uses VScrollView internally with absolutely-positioned items in a tall
 * content container. The scroll position drives which items are mounted.
 *
 * @example
 * ```vue
 * <script setup>
 * import { VFlatList } from '@thelacanians/vue-native-runtime'
 *
 * const data = Array.from({ length: 10000 }, (_, i) => ({ id: i, title: `Item ${i}` }))
 *
 * function renderItem({ item, index }) {
 *   return h('VView', { style: { padding: 16 } }, [
 *     h('VText', {}, `${item.title}`),
 *   ])
 * }
 * </script>
 *
 * <template>
 *   <VFlatList
 *     :data="data"
 *     :renderItem="renderItem"
 *     :itemHeight="52"
 *     :style="{ flex: 1 }"
 *     @endReached="loadMore"
 *   />
 * </template>
 * ```
 *
 * For slot-based usage:
 * ```vue
 * <VFlatList :data="data" :itemHeight="52" :style="{ flex: 1 }">
 *   <template #item="{ item, index }">
 *     <VText>{{ item.title }}</VText>
 *   </template>
 * </VFlatList>
 * ```
 */
export const VFlatList = defineComponent({
  name: 'VFlatList',

  props: {
    /** Array of data items to render. */
    data: {
      type: Array as PropType<any[]>,
      required: true,
    },
    /**
     * Render function for each item. Receives { item, index } and returns a VNode.
     * If not provided, the `#item` slot is used instead.
     */
    renderItem: {
      type: Function as PropType<(info: FlatListRenderItemInfo) => VNode>,
      default: undefined,
    },
    /** Extract a unique key from each item. Defaults to item.id, item.key, or index. */
    keyExtractor: {
      type: Function as PropType<(item: any, index: number) => string | number>,
      default: (item: any, index: number) => item?.id ?? item?.key ?? index,
    },
    /** Fixed height for each item in points. Required for virtualization math. */
    itemHeight: {
      type: Number,
      required: true,
    },
    /**
     * Number of viewport-heights to render above and below the visible area.
     * Higher values reduce blank flashes during fast scrolling but use more memory.
     * Default: 3 (3 viewports above + 3 below = 7 total viewports of items).
     */
    windowSize: {
      type: Number,
      default: 3,
    },
    /** Style for the outer scroll container. */
    style: {
      type: Object as PropType<ViewStyle>,
      default: () => ({}),
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
    /** Height of the header slot in points. Used to offset items below the header. */
    headerHeight: {
      type: Number,
      default: 0,
    },
    /**
     * How far from the end (in viewport fractions) to trigger endReached.
     * Default: 0.5 (trigger when within 50% of a viewport from the bottom).
     */
    endReachedThreshold: {
      type: Number,
      default: 0.5,
    },
  },

  emits: ['scroll', 'endReached'],

  setup(props, { slots, emit }) {
    const scrollOffset = ref(0)
    const viewportHeight = ref(0)
    let endReachedFired = false

    // Total scrollable content height (includes header when present)
    const hasHeader = computed(() => !!slots.header)
    const totalHeight = computed(() => {
      const itemsHeight = (props.data?.length ?? 0) * props.itemHeight
      return itemsHeight + (hasHeader.value ? props.headerHeight : 0)
    })

    // Compute which indices should be rendered
    const visibleRange = computed(() => {
      const vh = viewportHeight.value || props.itemHeight * 20 // Reasonable initial estimate
      const buffer = vh * props.windowSize
      const startPx = Math.max(0, scrollOffset.value - buffer)
      const endPx = scrollOffset.value + vh + buffer
      const startIdx = Math.floor(startPx / props.itemHeight)
      const endIdx = Math.min(
        Math.ceil(endPx / props.itemHeight),
        props.data?.length ?? 0,
      )
      return { start: startIdx, end: endIdx }
    })

    function onScroll(event: ScrollEvent) {
      scrollOffset.value = event.y ?? 0

      // Update viewport height from native layout info
      if (event.layoutHeight && event.layoutHeight > 0) {
        viewportHeight.value = event.layoutHeight
      }

      emit('scroll', event)

      // endReached detection
      const contentLength = totalHeight.value
      const offset = scrollOffset.value
      const vh = viewportHeight.value || props.itemHeight * 20
      const distanceFromEnd = contentLength - vh - offset
      const threshold = vh * props.endReachedThreshold

      if (distanceFromEnd < threshold && !endReachedFired) {
        endReachedFired = true
        emit('endReached')
      } else if (distanceFromEnd >= threshold) {
        endReachedFired = false
      }
    }

    return () => {
      const items = props.data ?? []
      const { start, end } = visibleRange.value

      // Build only visible item VNodes
      const children: VNode[] = []

      for (let i = start; i < end; i++) {
        const item = items[i]
        if (item === undefined) continue

        const key = props.keyExtractor(item, i)
        // renderItem returns a single VNode; slots return VNode[]
        const itemContent = props.renderItem
          ? [props.renderItem({ item, index: i })]
          : slots.item?.({ item, index: i }) ?? []

        children.push(
          h(
            'VView',
            {
              key,
              style: {
                position: 'absolute' as const,
                top: (hasHeader.value ? props.headerHeight : 0) + i * props.itemHeight,
                left: 0,
                right: 0,
                height: props.itemHeight,
              },
            },
            itemContent,
          ),
        )
      }

      // Header slot — positioned at the very top
      if (slots.header) {
        children.unshift(
          h('VView', { key: '__vfl_header__', style: { position: 'absolute' as const, top: 0, left: 0, right: 0 } }, slots.header()),
        )
      }

      // Empty state slot
      if (items.length === 0 && slots.empty) {
        return h(
          'VScrollView',
          {
            style: { ...props.style, flex: (props.style as any)?.flex ?? 1 },
            showsVerticalScrollIndicator: props.showsScrollIndicator,
            bounces: props.bounces,
          },
          [h('VView', { style: { flex: 1 } }, slots.empty())],
        )
      }

      // Inner container with total height for correct scrollbar
      const innerContainer = h(
        'VView',
        {
          key: '__vfl_container__',
          style: {
            height: totalHeight.value,
            width: '100%',
          },
        },
        children,
      )

      return h(
        'VScrollView',
        {
          style: { ...props.style, flex: (props.style as any)?.flex ?? 1 },
          showsVerticalScrollIndicator: props.showsScrollIndicator,
          bounces: props.bounces,
          onScroll,
        },
        [innerContainer],
      )
    }
  },
})
