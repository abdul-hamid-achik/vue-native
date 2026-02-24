import { defineComponent, h, ref, watch, type PropType } from '@vue/runtime-core'
import type { ImageStyle } from '../types/styles'

/**
 * VImage — the image display component in Vue Native.
 *
 * Maps to UIImageView on iOS. Loads images from URIs asynchronously
 * with built-in caching. Supports various resize modes.
 *
 * Exposes a reactive `loading` ref (via template ref) that is `true`
 * while the image is being fetched and `false` once it loads or errors.
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
  setup(props, { emit, expose }) {
    const loading = ref(true)

    // Reset loading state when the source URI changes.
    watch(
      () => props.source?.uri,
      () => {
        loading.value = true
      },
    )

    const onLoad = () => {
      loading.value = false
      emit('load')
    }

    const onError = (e: any) => {
      loading.value = false
      emit('error', e)
    }

    expose({ loading })

    return () =>
      h(
        'VImage',
        {
          ...props,
          onLoad,
          onError,
        },
      )
  },
})
