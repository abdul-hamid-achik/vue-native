import { defineComponent, h, ref, watch } from '@vue/runtime-core'
import type { PropType } from '@vue/runtime-core'
import { VView } from './VView'
import { VText } from './VText'
import { VPressable } from './VPressable'

export interface TabConfig {
  id: string
  label: string
  icon?: string
  badge?: number | string
}

/**
 * VTabBar - Tab bar navigation component
 *
 * @example
 * ```vue
 * <VTabBar
 *   :tabs="tabs"
 *   :activeTab="activeTab"
 *   @change="handleTabChange"
 * />
 * ```
 */
export const VTabBar = defineComponent({
  name: 'VTabBar',
  props: {
    /** Array of tab configurations */
    tabs: {
      type: Array as PropType<TabConfig[]>,
      required: true,
    },
    /** Currently active tab ID */
    activeTab: {
      type: String,
      required: true,
    },
    /** Position: 'top' | 'bottom' */
    position: {
      type: String as PropType<'top' | 'bottom'>,
      default: 'bottom',
    },
  },
  emits: ['change'],
  setup(props, { emit }) {
    const activeTab = ref(props.activeTab)

    watch(() => props.activeTab, (newVal) => {
      activeTab.value = newVal
    })

    const switchTab = (tabId: string) => {
      activeTab.value = tabId
      emit('change', tabId)
    }

    return () => h(VView, {
      style: {
        position: 'absolute',
        [props.position]: 0,
        left: 0,
        right: 0,
        backgroundColor: '#fff',
        borderTopWidth: 1,
        borderTopColor: '#e0e0e0',
        flexDirection: 'row',
        height: 60,
      },
    }, props.tabs.map((tab) => {
      const isActive = activeTab.value === tab.id
      return h(VPressable, {
        key: tab.id,
        style: {
          flex: 1,
          justifyContent: 'center',
          alignItems: 'center',
        },
        onPress: () => switchTab(tab.id),
        accessibilityLabel: tab.label,
        accessibilityRole: 'tab',
        accessibilityState: { selected: isActive },
      }, () => [
        tab.icon ? h(VText, { style: { fontSize: 24, marginBottom: 4 } }, () => tab.icon) : null,
        h(VText, {
          style: {
            fontSize: 12,
            fontWeight: isActive ? '600' : '400',
            color: isActive ? '#007AFF' : '#8E8E93',
          },
        }, () => tab.label),
        tab.badge
          ? h(VView, {
              style: {
                position: 'absolute',
                top: 8,
                right: '25%',
                backgroundColor: '#FF3B30',
                borderRadius: 10,
                minWidth: 20,
                height: 20,
                justifyContent: 'center',
                alignItems: 'center',
              },
            }, () => h(VText, {
              style: {
                color: '#fff',
                fontSize: 12,
                fontWeight: '600',
                paddingHorizontal: 6,
              },
            }, () => String(tab.badge)))
          : null,
      ])
    }))
  },
})
