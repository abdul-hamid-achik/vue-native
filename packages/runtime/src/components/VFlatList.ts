import { defineComponent, h, ref, computed, type PropType, type VNode } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

interface KeyedItem {
  id?: string | number
  key?: string | number
}

/**
 * Information provided to the renderItem function.
 */
export interface FlatListRenderItemInfo<T = unknown> {
  item: T
  index: number
}

function getDefaultItemKey(item: unknown, index: number): string | number {
  if (typeof item === 'object' && item !== null) {
    const keyedItem = item as KeyedItem
    return keyedItem.id ?? keyedItem.key ?? index
  }

  return index
}

function resolveFlexValue(style?: ViewStyle): number {
  return typeof style?.flex === 'number' ? style.flex : 1
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
const VFlatListBase = defineComponent({
  name: 'VFlatList',

  props: {
    /** Array of data items to render. */
    data: {
      type: Array as PropType<unknown[]>,
      required: true,
    },
    /**
     * Render function for each item. Receives { item, index } and returns a VNode.
     * If not provided, the `#item` slot is used instead.
     */
    renderItem: {
      type: Function as PropType<(info: FlatListRenderItemInfo<unknown>) => VNode>,
      default: undefined,
    },
    /** Extract a unique key from each item. Defaults to item.id, item.key, or index. */
    keyExtractor: {
      type: Function as PropType<(item: unknown, index: number) => string | number>,
      default: getDefaultItemKey,
    },
    /**
     * Fixed height for every item in points. When provided, virtualization uses
     * it directly (fast path, no measurement needed).
     */
    itemHeight: {
      type: Number,
      default: undefined,
    },
    /**
     * Estimated height for items whose real height is not yet measured. Used
     * for variable-height lists until the native side reports each item's actual
     * height via the `itemLayout` event. Ignored when `itemHeight` is set.
     * Default: 44.
     */
    estimatedItemHeight: {
      type: Number,
      default: 44,
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
    // Bumped whenever a measured height changes, to recompute cumulative offsets.
    const heightsVersion = ref(0)
    const measuredHeights = new Map<number, number>()
    let endReachedFired = false

    const hasHeader = computed(() => !!slots.header)
    const headerOffset = computed(() => (hasHeader.value ? props.headerHeight : 0))

    // Fixed-height fast path (no measurement) vs variable-height (estimated + measured).
    function heightFor(index: number): number {
      if (props.itemHeight != null) return props.itemHeight
      return measuredHeights.get(index) ?? props.estimatedItemHeight
    }

    // Cumulative top offsets: offsets[i] = top of item i, offsets[n] = content height.
    const offsets = computed(() => {
      void heightsVersion.value // recompute when measurements change
      const n = props.data?.length ?? 0
      const offs = new Array<number>(n + 1)
      offs[0] = headerOffset.value
      for (let i = 0; i < n; i++) {
        offs[i + 1] = offs[i] + heightFor(i)
      }
      return offs
    })

    const totalHeight = computed(() => {
      const offs = offsets.value
      return offs.length > 0 ? offs[offs.length - 1] : headerOffset.value
    })

    const visibleRange = computed(() => {
      const offs = offsets.value
      const n = props.data?.length ?? 0
      const est = props.itemHeight ?? props.estimatedItemHeight
      const vh = viewportHeight.value || est * 20
      const buffer = vh * props.windowSize
      const startPx = Math.max(0, scrollOffset.value - buffer)
      const endPx = scrollOffset.value + vh + buffer
      // Binary search: first item whose bottom edge is past startPx.
      let lo = 0
      let hi = n
      while (lo < hi) {
        const mid = (lo + hi) >> 1
        if (offs[mid + 1] <= startPx) lo = mid + 1
        else hi = mid
      }
      const start = lo
      let end = start
      while (end < n && offs[end] < endPx) end++
      return { start, end }
    })

    // Native reports each item's measured height via the `itemLayout` event so
    // variable-height lists can position items by their real (cumulative) heights.
    function onItemLayout(payload: { index?: unknown, height?: unknown }) {
      if (props.itemHeight != null) return // fixed heights need no measurement
      const index = typeof payload?.index === 'number' ? payload.index : -1
      const height = typeof payload?.height === 'number' ? payload.height : -1
      if (index < 0 || height <= 0) return
      if (measuredHeights.get(index) !== height) {
        measuredHeights.set(index, height)
        heightsVersion.value++
      }
    }

    function onScroll(event: ScrollEvent) {
      scrollOffset.value = event.y ?? 0

      if (event.layoutHeight && event.layoutHeight > 0) {
        viewportHeight.value = event.layoutHeight
      }

      emit('scroll', event)

      const contentLength = totalHeight.value
      const offset = scrollOffset.value
      const est = props.itemHeight ?? props.estimatedItemHeight
      const vh = viewportHeight.value || est * 20
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
      const offs = offsets.value
      const fixed = props.itemHeight

      const children: VNode[] = []

      for (let i = start; i < end; i++) {
        const item = items[i]
        if (item === undefined) continue

        const key = props.keyExtractor(item, i)
        const itemContent = props.renderItem
          ? [props.renderItem({ item, index: i })]
          : slots.item?.({ item, index: i }) ?? []

        // Fixed height: set it explicitly. Variable height: let the content size
        // the wrapper; native measures it and reports via `itemLayout`.
        const itemStyle: ViewStyle = fixed != null
          ? { position: 'absolute' as const, top: offs[i], left: 0, right: 0, height: fixed }
          : { position: 'absolute' as const, top: offs[i], left: 0, right: 0 }

        children.push(
          h(
            'VView',
            {
              key,
              style: itemStyle,
              __flatListIndex: i,
              onItemLayout,
            },
            itemContent,
          ),
        )
      }

      if (slots.header) {
        children.unshift(
          h('VView', { key: '__vfl_header__', style: { position: 'absolute' as const, top: 0, left: 0, right: 0 } }, slots.header()),
        )
      }

      if (items.length === 0 && slots.empty) {
        return h(
          'VScrollView',
          {
            style: { ...props.style, flex: resolveFlexValue(props.style) },
            showsVerticalScrollIndicator: props.showsScrollIndicator,
            bounces: props.bounces,
          },
          [h('VView', { style: { flex: 1 } }, slots.empty())],
        )
      }

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
          style: { ...props.style, flex: resolveFlexValue(props.style) },
          showsVerticalScrollIndicator: props.showsScrollIndicator,
          bounces: props.bounces,
          onScroll,
        },
        [innerContainer],
      )
    }
  },
})

/**
 * VFlatList typed as a generic component so `renderItem`/`keyExtractor` infer
 * the item type `T` from `data` in templates. The runtime value is unchanged
 * (still the defineComponent object); only the public type is generic.
 */
export const VFlatList = VFlatListBase as unknown as <T = unknown>(
  props: {
    data: T[]
    renderItem?: (info: FlatListRenderItemInfo<T>) => VNode
    keyExtractor?: (item: T, index: number) => string | number
    /** Fixed height for every item (fast path). Omit for variable-height lists. */
    itemHeight?: number
    /** Estimated height for unmeasured items in variable-height lists. Default 44. */
    estimatedItemHeight?: number
    windowSize?: number
    style?: ViewStyle
    showsScrollIndicator?: boolean
    bounces?: boolean
    headerHeight?: number
    endReachedThreshold?: number
  } & Record<string, unknown>,
) => VNode
