import { defineComponent, h, ref, type PropType, type VNode } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'
import { usePlatform } from '../composables/usePlatform'

/**
 * VList — A virtualized list component backed by UITableView on iOS.
 *
 * Renders each item in `data` via the default `#item` slot.
 * Supports thousands of items with smooth scrolling and cell recycling.
 *
 * Only a window of items (visible rows plus a configurable buffer) is mounted
 * as native views; rows outside the window are replaced by two spacer views
 * that preserve the native scroll content size. This keeps live-view memory at
 * O(window) instead of O(n) for very large datasets. Small lists (length <=
 * `windowSize * 2`) render every item without windowing.
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
const VListBase = defineComponent({
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
    /**
     * Estimated extent per row along the scroll axis in points (height for
     * vertical lists, width for horizontal ones). Used to estimate which items
     * fall inside the render window before layout runs. Default: 44
     */
    estimatedItemHeight: {
      type: Number,
      default: 44,
    },
    /**
     * Number of extra items to mount above and below the visible window as a
     * buffer. Higher values reduce blank flashes during fast scrolling but use
     * more memory. Lists with length <= `windowSize * 2` render every item
     * without windowing. Default: 10
     */
    windowSize: {
      type: Number,
      default: 10,
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

    // Scroll position along the active axis (x for horizontal, y for vertical)
    // and the viewport extent reported by the native scroll event. These drive
    // the render window. Updated on every scroll event (unthrottled) so the
    // window tracks fast scrolls; only the re-emitted `scroll` event is throttled.
    const scrollOffset = ref(0)
    const viewportExtent = ref(0)

    const onScroll = (e: {
      x: number
      y: number
      contentWidth?: number
      contentHeight?: number
      layoutWidth?: number
      layoutHeight?: number
    }) => {
      // Track the window-driving state on every event.
      if (props.horizontal) {
        scrollOffset.value = e.x ?? 0
        if (e.layoutWidth && e.layoutWidth > 0) viewportExtent.value = e.layoutWidth
      } else {
        scrollOffset.value = e.y ?? 0
        if (e.layoutHeight && e.layoutHeight > 0) viewportExtent.value = e.layoutHeight
      }

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

      // Item slots — windowed for large datasets.
      //
      // For small lists we mount every item (no windowing) so the simple case
      // keeps its exact previous behavior. For large lists we only mount the
      // visible window plus a buffer, and insert a leading/trailing spacer view
      // whose extent equals the unmounted items so the native scroll content
      // size (and thus scroll position / endReached) stays correct.
      const total = items.length
      const estimated = props.estimatedItemHeight
      const windowingActive = total > props.windowSize * 2

      let startIndex = 0
      let endIndex = total - 1
      if (windowingActive) {
        // Fall back to a ~20-item viewport estimate until the native scroll
        // event reports the real viewport extent.
        const viewport = viewportExtent.value > 0 ? viewportExtent.value : estimated * 20
        const visibleCount = Math.max(1, Math.ceil(viewport / estimated))
        const firstVisible = Math.floor(scrollOffset.value / estimated)
        startIndex = Math.max(0, firstVisible - props.windowSize)
        endIndex = Math.min(total - 1, firstVisible + visibleCount + props.windowSize)

        const topExtent = startIndex * estimated
        if (topExtent > 0) {
          children.push(
            h('VView', {
              key: '__spacer_top__',
              style: props.horizontal
                ? { width: topExtent, flexShrink: 0 }
                : { height: topExtent, flexShrink: 0 },
            }),
          )
        }
      }

      for (let index = startIndex; index <= endIndex; index++) {
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

      if (windowingActive) {
        const bottomExtent = (total - endIndex - 1) * estimated
        if (bottomExtent > 0) {
          children.push(
            h('VView', {
              key: '__spacer_bottom__',
              style: props.horizontal
                ? { width: bottomExtent, flexShrink: 0 }
                : { height: bottomExtent, flexShrink: 0 },
            }),
          )
        }
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

/**
 * VList typed as a generic component so the `#item` slot scope infers the item
 * type `T` from `data`. The runtime value is unchanged (still the defineComponent
 * object); only the public type is generic.
 */
export const VList = VListBase as unknown as <T = unknown>(
  props: {
    data: T[]
    keyExtractor?: (item: T, index: number) => string
    estimatedItemHeight?: number
    windowSize?: number
    showsScrollIndicator?: boolean
    bounces?: boolean
    horizontal?: boolean
    style?: ViewStyle
    onScroll?: (e: unknown) => void
    onEndReached?: () => void
    slots?: {
      item?: (info: { item: T, index: number }) => VNode[]
      header?: () => VNode[]
      empty?: () => VNode[]
      footer?: () => VNode[]
    }
  } & Record<string, unknown>,
) => VNode
