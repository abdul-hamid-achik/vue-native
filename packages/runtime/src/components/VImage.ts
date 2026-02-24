import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ImageStyle } from '../types/styles'

/**
 * VImage — the image display component in Vue Native.
 *
 * Maps to UIImageView on iOS. Loads images from URIs asynchronously
 * with built-in caching. Supports various resize modes.
 *
 * @example
 * ```vue
 * <VImage
 *   :source="{ uri: 'https://example.com/photo.jpg' }"
 *   resizeMode="cover"
 *   :style="{ width: 200, height: 150 }"
 *   @load="onImageLoad"
 *   @error="onImageError"
 * />
 * ```
 */
export const VImage = defineComponent({
  name: 'VImage',
  props: {
    source: Object as () => { uri: string },
    resizeMode: {
      type: String as () => 'cover' | 'contain' | 'stretch' | 'center',
      default: 'cover',
    },
    style: Object as PropType<ImageStyle>,
    testID: String,
    accessibilityLabel: String,
    accessibilityRole: String,
    accessibilityHint: String,
    accessibilityState: Object,
  },
  emits: ['load', 'error'],
  setup(props, { emit }) {
    return () =>
      h(
        'VImage',
        {
          ...props,
          onLoad: () => emit('load'),
          onError: (e: any) => emit('error', e),
        },
      )
  },
})
