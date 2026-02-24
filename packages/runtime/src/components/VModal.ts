import { defineComponent, h, ref, watch, onUnmounted, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

/**
 * Window-level modal overlay component.
 * Renders its children in a full-screen overlay on the key window.
 *
 * @example
 * <VModal :visible="showModal" @dismiss="showModal = false">
 *   <VView style="..."><VText>Hello</VText></VView>
 * </VModal>
 */
export const VModal = defineComponent({
  name: 'VModal',

  props: {
    visible: {
      type: Boolean,
      default: false,
    },
    style: {
      type: Object as PropType<ViewStyle>,
      default: () => ({}),
    },
  },

  emits: ['dismiss'],

  setup(props, { slots, emit }) {
    // Debounce visible prop to prevent animation jank from rapid toggles
    const debouncedVisible = ref(props.visible)
    let visibleTimer: ReturnType<typeof setTimeout> | undefined

    watch(
      () => props.visible,
      (val) => {
        if (visibleTimer) clearTimeout(visibleTimer)
        visibleTimer = setTimeout(() => {
          debouncedVisible.value = val
        }, 50)
      },
    )

    onUnmounted(() => {
      if (visibleTimer) clearTimeout(visibleTimer)
    })

    return () =>
      h(
        'VModal',
        {
          visible: debouncedVisible.value,
          style: props.style,
          onDismiss: () => emit('dismiss'),
        },
        slots.default?.() ?? [],
      )
  },
})
