import { defineComponent, h, ref, watch } from '@vue/runtime-core'
import type { PropType } from '@vue/runtime-core'
import { VView } from './VView'
import { VText } from './VText'
import { VPressable } from './VPressable'

export type TabConfig = {
  label: string
  icon?: string
  badge?: number | string
} & (
  | { id: string, name?: string }
  | { id?: string, name: string }
)

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
      default: undefined,
    },
    /** Currently active tab name/id for v-model */
    modelValue: {
      type: String,
      default: undefined,
    },
    /** Position: 'top' | 'bottom' */
    position: {
      type: String as PropType<'top' | 'bottom'>,
      default: 'bottom',
    },
    activeColor: { type: String, default: '#007AFF' },
    inactiveColor: { type: String, default: '#8E8E93' },
    backgroundColor: { type: String, default: '#fff' },
  },
  emits: ['change', 'update:modelValue'],
  setup(props, { emit }) {
    const activeTab = ref(props.modelValue ?? props.activeTab ?? '')

    watch(() => props.activeTab, (newVal) => {
      if (newVal !== undefined) activeTab.value = newVal
    })

    watch(() => props.modelValue, (newVal) => {
      if (newVal !== undefined) activeTab.value = newVal
    })

    const switchTab = (tabId: string) => {
      activeTab.value = tabId
      emit('change', tabId)
      emit('update:modelValue', tabId)
    }

    return () => h(VView, {
      style: {
        position: 'absolute',
        [props.position]: 0,
        left: 0,
        right: 0,
        backgroundColor: props.backgroundColor,
        ...(props.position === 'top'
          ? { borderBottomWidth: 1, borderBottomColor: '#e0e0e0' }
          : { borderTopWidth: 1, borderTopColor: '#e0e0e0' }),
        flexDirection: 'row',
        height: 60,
      },
    }, () => props.tabs.map((tab) => {
      const tabId = tab.name ?? tab.id
      // TypeScript callers must supply an id or name, but keep malformed
      // JavaScript configuration from creating duplicate empty Vue keys.
      if (tabId === undefined || tabId === '') return null
      const isActive = activeTab.value === tabId
      return h(VPressable, {
        key: tabId,
        style: {
          flex: 1,
          justifyContent: 'center',
          alignItems: 'center',
        },
        onPress: () => switchTab(tabId),
        accessibilityLabel: tab.label,
        accessibilityRole: 'tab',
        accessibilityState: { selected: isActive },
      }, () => [
        tab.icon ? h(VText, { style: { fontSize: 24, marginBottom: 4, color: isActive ? props.activeColor : props.inactiveColor } }, () => tab.icon) : null,
        h(VText, {
          style: {
            fontSize: 12,
            fontWeight: isActive ? '600' : '400',
            color: isActive ? props.activeColor : props.inactiveColor,
          },
        }, () => tab.label),
        tab.badge !== undefined && tab.badge !== null && tab.badge !== ''
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
