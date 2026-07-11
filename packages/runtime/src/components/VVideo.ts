import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

/**
 * VVideo — the video playback component in Vue Native.
 *
 * Maps to AVPlayer on Apple platforms and MediaPlayer on Android.
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
    /** Reserved for native transport controls; currently has no effect. */
    controls: { type: Boolean, default: true },
    volume: { type: Number, default: 1.0 },
    resizeMode: {
      type: String as () => 'cover' | 'contain' | 'stretch' | 'center',
      default: 'cover',
    },
    /** Reserved for native poster rendering; currently has no effect. */
    poster: String,
    style: Object as PropType<ViewStyle>,
    testID: String,
    accessibilityLabel: String,
  },
  emits: ['ready', 'play', 'pause', 'end', 'error', 'progress'],
  setup(props, { emit }) {
    return () =>
      h('VVideo', {
        // Playback intent must reach native before a source can become ready.
        // In particular, the default paused=false must not override
        // autoplay=false by eagerly starting a newly-created player.
        autoplay: props.autoplay,
        paused: props.paused,
        source: props.source,
        loop: props.loop,
        volume: props.volume,
        muted: props.muted,
        controls: props.controls,
        resizeMode: props.resizeMode,
        poster: props.poster,
        style: props.style,
        testID: props.testID,
        accessibilityLabel: props.accessibilityLabel,
        onReady: (event: unknown) => emit('ready', event),
        onPlay: () => emit('play'),
        onPause: () => emit('pause'),
        onEnd: () => emit('end'),
        onError: (event: unknown) => emit('error', event),
        onProgress: (event: unknown) => emit('progress', event),
      })
  },
})
