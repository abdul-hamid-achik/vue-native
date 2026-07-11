# VVideo

A video player component. Maps to `AVPlayer` on Apple platforms and
`MediaPlayer` on Android.

The current native implementations support streaming and local playback with
programmatic play/pause state. Build transport controls in Vue when you need a
play button, seeking, or fullscreen behavior.

## Usage

```vue
<VVideo
  :source="{ uri: 'https://example.com/video.mp4' }"
  :style="{ width: '100%', aspectRatio: 16 / 9 }"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `source` | `{ uri: string }` | -- | Video source object containing a `uri` string |
| `autoplay` | `Boolean` | `false` | Begins playback when the source becomes ready, unless `paused` is `true` |
| `loop` | `Boolean` | `false` | Restarts playback from the beginning when it reaches the end |
| `muted` | `Boolean` | `false` | Mutes audio output |
| `paused` | `Boolean` | `false` | Pauses playback when `true`; after readiness, changing it to `false` starts or resumes playback |
| `controls` | `Boolean` | `true` | Reserved for native transport controls; currently has no effect |
| `volume` | `Number` | `1.0` | Audio volume from `0.0` (silent) to `1.0` (full) |
| `resizeMode` | `'cover' \| 'contain' \| 'stretch' \| 'center'` | `'cover'` | How the video is scaled within the frame |
| `poster` | `String` | -- | Reserved for poster rendering; currently has no effect |
| `style` | `ViewStyle` | -- | Layout + appearance styles |
| `testID` | `String` | -- | Test identifier for end-to-end testing |
| `accessibilityLabel` | `String` | -- | Accessibility label read by screen readers |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `ready` | -- | Emitted when the video is loaded and ready to play |
| `play` | -- | Reserved for playback-state events; not currently emitted |
| `pause` | -- | Reserved for playback-state events; not currently emitted |
| `end` | -- | Emitted when playback reaches the end |
| `error` | `{ message: string }` | Emitted when a playback error occurs |
| `progress` | `{ currentTime: number, duration: number }` | Emitted periodically during playback with time information |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const isPaused = ref(true)
const progress = ref(0)
const duration = ref(0)

function onProgress({ currentTime, duration: dur }) {
  progress.value = currentTime
  duration.value = dur
}

function formatTime(seconds) {
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60)
  return `${m}:${s.toString().padStart(2, '0')}`
}
</script>

<template>
  <VView :style="{ flex: 1, backgroundColor: '#000' }">
    <VVideo
      :source="{ uri: 'https://example.com/sample-video.mp4' }"
      :paused="isPaused"
      resizeMode="contain"
      :style="{ width: '100%', aspectRatio: 16 / 9 }"
      @ready="() => console.log('Video ready')"
      @end="() => (isPaused = true)"
      @error="(e) => console.warn('Playback error:', e.message)"
      @progress="onProgress"
    />

    <VView :style="{ padding: 16, gap: 12 }">
      <VText :style="{ color: '#fff', fontSize: 13 }">
        {{ formatTime(progress) }} / {{ formatTime(duration) }}
      </VText>

      <VButton
        :style="{
          backgroundColor: '#fff',
          padding: 12,
          borderRadius: 8,
          alignItems: 'center',
        }"
        :onPress="() => (isPaused = !isPaused)"
      >
        <VText :style="{ fontWeight: '600' }">
          {{ isPaused ? 'Play' : 'Pause' }}
        </VText>
      </VButton>
    </VView>
  </VView>
</template>
```

## Current platform limitations

- `controls` and `poster` are retained for API compatibility but are not yet
  rendered by the native players. Use Vue Native views for custom controls and
  an overlaid `VImage` for a poster.
- `play` and `pause` listeners are retained for API compatibility but are not
  yet emitted. Treat your `paused` state as the source of truth.
- Android currently uses `SurfaceView`, so `resizeMode` does not yet provide the
  same scaling modes as `AVPlayerLayer`.
- Automatic playback through `autoplay` and programmatic playback through
  `paused` are implemented on iOS, Android, and macOS.
