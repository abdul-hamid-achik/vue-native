# VVideo

A video player component. Maps to `AVPlayer` on iOS and `MediaPlayer` on Android.

Supports streaming and local video playback with built-in transport controls.

## Usage

```vue
<VVideo
  :source="{ uri: 'https://example.com/video.mp4' }"
  :controls="true"
  :style="{ width: '100%', aspectRatio: 16 / 9 }"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `source` | `{ uri: string }` | -- | Video source object containing a `uri` string |
| `autoplay` | `Boolean` | `false` | Automatically begins playback when the source is ready |
| `loop` | `Boolean` | `false` | Restarts playback from the beginning when it reaches the end |
| `muted` | `Boolean` | `false` | Mutes audio output |
| `paused` | `Boolean` | `false` | Pauses playback when `true` |
| `controls` | `Boolean` | `true` | Shows native transport controls (play/pause, seek, fullscreen) |
| `volume` | `Number` | `1.0` | Audio volume from `0.0` (silent) to `1.0` (full) |
| `resizeMode` | `'cover' \| 'contain' \| 'stretch' \| 'center'` | `'cover'` | How the video is scaled within the frame |
| `poster` | `String` | -- | URL of a poster image displayed before playback starts |
| `style` | `ViewStyle` | -- | Layout + appearance styles |
| `testID` | `String` | -- | Test identifier for end-to-end testing |
| `accessibilityLabel` | `String` | -- | Accessibility label read by screen readers |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `ready` | -- | Emitted when the video is loaded and ready to play |
| `play` | -- | Emitted when playback starts or resumes |
| `pause` | -- | Emitted when playback is paused |
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
      :controls="true"
      resizeMode="contain"
      poster="https://example.com/poster.jpg"
      :style="{ width: '100%', aspectRatio: 16 / 9 }"
      @ready="() => console.log('Video ready')"
      @play="() => (isPaused = false)"
      @pause="() => (isPaused = true)"
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
