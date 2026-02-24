import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

/**
 * VVideo — the video playback component in Vue Native.
 *
 * Maps to AVPlayer on iOS and MediaPlayer on Android.
 * Supports inline video playback with progress reporting.
 *
 * @example
 * ```vue
 * <VVideo
 *   :source="{ uri: 'https://example.com/video.mp4' }"
 *   :autoplay="true"
 *   :loop="false"
 *   :muted="false"
 *   resizeMode="cover"
 *   :style="{ width: '100%', height: 200 }"
 *   @ready="onReady"
 *   @progress="onProgress"
 *   @end="onEnd"
 * />
 * ```
 */
export const VVideo = defineComponent({
  name: 'VVideo',
  props: {
    source: Object as () => { uri: string },
    autoplay: { type: Boolean, default: false },
    loop: { type: Boolean, default: false },
    muted: { type: Boolean, default: false },
    paused: { type: Boolean, default: false },
    controls: { type: Boolean, default: true },
    volume: { type: Number, default: 1.0 },
    resizeMode: {
      type: String as () => 'cover' | 'contain' | 'stretch' | 'center',
      default: 'cover',
    },
    poster: String,
    style: Object as PropType<ViewStyle>,
    testID: String,
    accessibilityLabel: String,
  },
  emits: ['ready', 'play', 'pause', 'end', 'error', 'progress'],
  setup(props, { emit }) {
    return () =>
      h('VVideo', {
        ...props,
        onReady: (e: any) => emit('ready', e),
        onPlay: () => emit('play'),
        onPause: () => emit('pause'),
        onEnd: () => emit('end'),
        onError: (e: any) => emit('error', e),
        onProgress: (e: any) => emit('progress', e),
      })
  },
})
