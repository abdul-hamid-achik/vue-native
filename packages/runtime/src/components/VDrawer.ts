import { defineComponent, h, inject, provide, ref, watch } from '@vue/runtime-core'
import type { PropType, VNode } from '@vue/runtime-core'
import { VView } from './VView'
import { VText } from './VText'
import { VPressable } from './VPressable'

const drawerContextKey = Symbol('VDrawerContext')

interface DrawerContext {
  close: () => void
  shouldCloseOnPress: () => boolean
}

/**
 * VDrawer - Drawer navigation component (side menu)
 *
 * @example
 * ```vue
 * <VDrawer v-model:open="drawerOpen">
 *   <template #header>
 *     <VText>Menu Header</VText>
 *   </template>
 *   <VDrawer.Item
 *     icon="🏠"
 *     label="Home"
 *     @press="navigateTo('home')"
 *   />
 * </VDrawer>
 * ```
 */
export const VDrawer = defineComponent({
  name: 'VDrawer',
  props: {
    /** Whether the drawer is open */
    open: {
      type: Boolean,
      default: false,
    },
    /** Drawer position: 'left' | 'right' */
    position: {
      type: String as PropType<'left' | 'right'>,
      default: 'left',
    },
    /** Drawer width */
    width: {
      type: Number,
      default: 280,
    },
    /** Close on item press */
    closeOnPress: {
      type: Boolean,
      default: true,
    },
  },
  emits: ['update:open', 'close'],
  setup(props, { attrs, slots, emit }) {
    const isOpen = ref(props.open)

    watch(() => props.open, (value) => {
      isOpen.value = value
    })

    const closeDrawer = () => {
      isOpen.value = false
      emit('update:open', false)
      emit('close')
    }

    provide<DrawerContext>(drawerContextKey, {
      close: closeDrawer,
      shouldCloseOnPress: () => props.closeOnPress,
    })

    return () => {
      if (!isOpen.value && !slots.default) {
        return null
      }

      const overlayStyle = {
        position: 'absolute' as const,
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        opacity: isOpen.value ? 1 : 0,
        zIndex: 999,
      }

      const drawerStyle = {
        position: 'absolute' as const,
        top: 0,
        [props.position]: 0,
        width: props.width,
        height: '100%',
        backgroundColor: '#fff',
        transform: [
          { translateX: isOpen.value ? 0 : (props.position === 'left' ? -props.width : props.width) },
        ],
        zIndex: 1000,
      }

      const drawerProps = {
        ...attrs,
        style: {
          ...drawerStyle,
          ...((attrs.style && typeof attrs.style === 'object' && !Array.isArray(attrs.style))
            ? attrs.style as Record<string, unknown>
            : {}),
        },
      }

      const drawerChildren: VNode[] = []

      if (slots.header) {
        drawerChildren.push(...slots.header())
      }

      if (slots.default) {
        drawerChildren.push(...(slots.default({ close: closeDrawer }) ?? []))
      }

      return [
        // Overlay
        isOpen.value
          ? h(VPressable, {
              style: overlayStyle,
              onPress: closeDrawer,
              accessibilityLabel: 'Close menu',
            })
          : null,

        // Drawer
        h(VView, drawerProps, () => drawerChildren),
      ]
    }
  },
})

/**
 * VDrawer.Item - Drawer menu item component
 */
export const VDrawerItem = defineComponent({
  name: 'VDrawerItem',
  props: {
    /** Icon (emoji or icon name) */
    icon: {
      type: String,
      default: '',
    },
    /** Label text */
    label: {
      type: String,
      required: true,
    },
    /** Badge count */
    badge: {
      type: [Number, String],
      default: null,
    },
    /** Disabled state */
    disabled: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['press'],
  setup(props, { slots, emit }) {
    const drawer = inject<DrawerContext | null>(drawerContextKey, null)

    const handlePress = () => {
      if (props.disabled) return
      emit('press')
      if (drawer?.shouldCloseOnPress()) {
        drawer.close()
      }
    }

    return () => h(VPressable, {
      style: {
        flexDirection: 'row',
        alignItems: 'center',
        padding: 16,
        borderBottomWidth: 1,
        borderBottomColor: '#f0f0f0',
        opacity: props.disabled ? 0.5 : 1,
      },
      onPress: handlePress,
      disabled: props.disabled,
      accessibilityLabel: props.label,
      accessibilityRole: 'menuitem',
      accessibilityState: { disabled: props.disabled },
    }, () => {
      const children: VNode[] = []

      if (props.icon) {
        children.push(
          h(VText, {
            style: {
              fontSize: 24,
              marginRight: 16,
              width: 32,
              textAlign: 'center',
            },
          }, () => props.icon),
        )
      }

      children.push(
        h(VText, {
          style: {
            flex: 1,
            fontSize: 16,
            color: props.disabled ? '#999' : '#333',
          },
        }, () => props.label),
      )

      if (props.badge) {
        children.push(
          h(VView, {
            style: {
              backgroundColor: '#007AFF',
              borderRadius: 12,
              minWidth: 24,
              height: 24,
              justifyContent: 'center',
              alignItems: 'center',
              paddingHorizontal: 8,
            },
          }, () => h(VText, {
            style: {
              color: '#fff',
              fontSize: 12,
              fontWeight: '600',
            },
          }, () => String(props.badge))),
        )
      }

      if (slots.default) {
        children.push(...(slots.default() ?? []))
      }

      return children
    })
  },
})

/**
 * VDrawer.Section - Drawer section divider
 */
export const VDrawerSection = defineComponent({
  name: 'VDrawerSection',
  props: {
    /** Section title */
    title: {
      type: String,
      default: '',
    },
  },
  setup(props, { slots }) {
    return () => h(VView, {
      style: {
        paddingVertical: 8,
        paddingHorizontal: 16,
        backgroundColor: '#f9f9f9',
        borderBottomWidth: 1,
        borderBottomColor: '#e0e0e0',
      },
    }, () => {
      const children: VNode[] = []

      if (props.title) {
        children.push(
          h(VText, {
            style: {
              fontSize: 13,
              fontWeight: '600',
              color: '#666',
              textTransform: 'uppercase',
              letterSpacing: 0.5,
            },
          }, () => props.title),
        )
      }

      if (slots.default) {
        children.push(...(slots.default() ?? []))
      }

      return children
    })
  },
})

VDrawer.Item = VDrawerItem
VDrawer.Section = VDrawerSection
