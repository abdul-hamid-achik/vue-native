import { defineComponent, h } from '@vue/runtime-core'

/**
 * VSectionList — A sectioned list component backed by UITableView with sections on iOS.
 *
 * Renders grouped data with section headers. Each section has a title and
 * an array of data items rendered via the #item slot.
 *
 * @example
 * <VSectionList
 *   :sections="[
 *     { title: 'Fruits', data: ['Apple', 'Banana'] },
 *     { title: 'Vegetables', data: ['Carrot', 'Pea'] },
 *   ]"
 *   :estimatedItemHeight="48"
 *   :style="{ flex: 1 }"
 * >
 *   <template #sectionHeader="{ section }">
 *     <VText :style="{ fontWeight: 'bold', padding: 8 }">{{ section.title }}</VText>
 *   </template>
 *   <template #item="{ item, index, section }">
 *     <VText :style="{ padding: 12 }">{{ item }}</VText>
 *   </template>
 * </VSectionList>
 */

interface Section {
  title: string
  data: any[]
}

export const VSectionList = defineComponent({
  name: 'VSectionList',

  props: {
    /** Array of section objects, each with a title and data array */
    sections: {
      type: Array as () => Section[],
      required: true,
    },
    /** Extract a unique key from each item. Defaults to index as string. */
    keyExtractor: {
      type: Function as unknown as () => (item: any, index: number) => string,
      default: (_item: any, index: number) => String(index),
    },
    /** Estimated height per row in points. Default: 44 */
    estimatedItemHeight: {
      type: Number,
      default: 44,
    },
    /** Whether section headers stick to the top when scrolling. Default: true */
    stickySectionHeaders: {
      type: Boolean,
      default: true,
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
    style: {
      type: Object,
      default: () => ({}),
    },
  },

  emits: ['scroll', 'endReached'],

  setup(props, { slots, emit }) {
    return () => {
      const sections = props.sections ?? []

      const children: any[] = []

      // Header slot
      if (slots.header) {
        children.push(
          h('VView', { key: '__header__', style: { flexShrink: 0 } }, slots.header()),
        )
      }

      // Empty state slot (shown when all sections are empty)
      const totalItems = sections.reduce((sum, s) => sum + (s.data?.length ?? 0), 0)
      if (totalItems === 0 && slots.empty) {
        children.push(
          h('VView', { key: '__empty__', style: { flexShrink: 0 } }, slots.empty()),
        )
      }

      // Render sections with headers and items
      for (let sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
        const section = sections[sectionIndex]

        // Section header
        if (slots.sectionHeader) {
          children.push(
            h(
              'VView',
              {
                key: `__section_header_${sectionIndex}__`,
                __sectionHeader: true,
                style: { flexShrink: 0 },
              },
              slots.sectionHeader({ section, index: sectionIndex }),
            ),
          )
        }

        // Section items
        const items = section.data ?? []
        for (let itemIndex = 0; itemIndex < items.length; itemIndex++) {
          const item = items[itemIndex]
          children.push(
            h(
              'VView',
              {
                key: `${sectionIndex}_${props.keyExtractor(item, itemIndex)}`,
                style: { flexShrink: 0 },
              },
              slots.item?.({ item, index: itemIndex, section }) ?? [],
            ),
          )
        }

        // Section footer
        if (slots.sectionFooter) {
          children.push(
            h(
              'VView',
              {
                key: `__section_footer_${sectionIndex}__`,
                style: { flexShrink: 0 },
              },
              slots.sectionFooter({ section, index: sectionIndex }),
            ),
          )
        }
      }

      // Footer slot
      if (slots.footer) {
        children.push(
          h('VView', { key: '__footer__', style: { flexShrink: 0 } }, slots.footer()),
        )
      }

      return h(
        'VSectionList',
        {
          style: props.style,
          estimatedItemHeight: props.estimatedItemHeight,
          stickySectionHeaders: props.stickySectionHeaders,
          showsScrollIndicator: props.showsScrollIndicator,
          bounces: props.bounces,
          onScroll: (e: { x: number, y: number }) => emit('scroll', e),
          onEndReached: () => emit('endReached'),
        },
        children,
      )
    }
  },
})
