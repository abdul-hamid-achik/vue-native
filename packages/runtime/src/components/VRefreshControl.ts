import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

/**
 * VRefreshControl — a pull-to-refresh indicator component.
 *
 * Designed to be used as a child of VScrollView or VList. When the user
 * pulls down past the scroll boundary, the onRefresh callback fires.
 * Set the refreshing prop to true while loading data, then false when done.
 *
 * On iOS this attaches a UIRefreshControl to the parent UIScrollView.
 * On Android this configures the parent SwipeRefreshLayout.
 *
 * @example
 * ```vue
 * <VScrollView :style="{ flex: 1 }">
 *   <VRefreshControl
 *     :refreshing="isLoading"
 *     :onRefresh="handleRefresh"
 *     tintColor="#007AFF"
 *   />
 *   <VText>Content here</VText>
 * </VScrollView>
 * ```
 */
export const VRefreshControl = defineComponent({
  name: 'VRefreshControl',
  props: {
    refreshing: {
      type: Boolean,
      default: false,
    },
    onRefresh: Function as PropType<() => void>,
    tintColor: String,
    title: String,
    style: Object as PropType<ViewStyle>,
  },
  setup(props) {
    return () =>
      h('VRefreshControl', {
        refreshing: props.refreshing,
        onRefresh: props.onRefresh,
        tintColor: props.tintColor,
        title: props.title,
      })
  },
})
