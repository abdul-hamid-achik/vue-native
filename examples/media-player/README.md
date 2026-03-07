# Media Player

A media player demonstrating video and audio playback controls.

## What It Demonstrates

- **Components:** VVideo, VView, VButton, VText, VSlider
- **Composables:** `useAudio`, `usePermissions`
- **Patterns:**
  - Video playback
  - Audio controls
  - Progress tracking
  - Play/pause state

## Key Features

- Video player with controls
- Play/pause toggle
- Progress slider
- Volume control
- Fullscreen support

## How to Run

```bash
cd examples/media-player
bun install
bun vue-native dev
```

## Key Concepts

### Video Playback

```typescript
const videoRef = ref(null)
const isPlaying = ref(false)
const progress = ref(0)

function togglePlay() {
  if (isPlaying.value) {
    videoRef.value?.pause()
  } else {
    videoRef.value?.play()
  }
  isPlaying.value = !isPlaying.value
}
```

### Progress Tracking

```typescript
function onTimeUpdate(event) {
  progress.value = (event.currentTime / event.duration) * 100
}

function seek(position) {
  const time = (position / 100) * videoRef.value.duration
  videoRef.value.seekTo(time)
}
```

## Learn More

- [VVideo Component](../../docs/src/components/VVideo.md)
- [useAudio](../../docs/src/composables/useAudio.md)
- [VSlider Component](../../docs/src/components/VSlider.md)
