import { defineComponent, h, type PropType } from '@vue/runtime-core'
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
    return () =>
      h(
        'VModal',
        {
          visible: props.visible,
          style: props.style,
          onDismiss: () => emit('dismiss'),
        },
        slots.default?.() ?? [],
      )
  },
})
