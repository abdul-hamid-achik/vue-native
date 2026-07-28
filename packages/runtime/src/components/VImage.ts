import { defineComponent, h, ref, watch, type PropType } from '@vue/runtime-core'
import type { ImageStyle } from '../types/styles'

/**
 * Image source. Provide `uri` for a remote/absolute URL, or `asset` to load a
 * bundled image by name (iOS Asset Catalog / macOS named image / Android
 * `res/drawable` resource). Exactly one should be set.
 */
export interface ImageSource {
  uri?: string
  asset?: string
}

/**
 * VImage — the image display component in Vue Native.
 *
 * Maps to UIImageView on iOS. Loads images from URIs asynchronously
 * with built-in caching, or from bundled assets by name. Supports various
 * resize modes.
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
 *
 * <!-- bundled asset -->
 * <VImage :source="{ asset: 'logo' }" :style="{ width: 120, height: 40 }" />
 * ```
 */
export const VImage = defineComponent({
  name: 'VImage',
  props: {
    source: Object as PropType<ImageSource>,
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

    // Reset loading state when the source (uri or asset) changes.
    watch(
      () => [props.source?.uri, props.source?.asset],
      () => {
        loading.value = true
      },
    )

    const onLoad = () => {
      loading.value = false
      emit('load')
    }

    const onError = (event: unknown) => {
      loading.value = false
      emit('error', event)
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
