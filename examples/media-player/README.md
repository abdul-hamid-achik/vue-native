# Media Player

A media player demonstrating video and audio playback controls.

> **Requires a native host.** This directory ships Vue source and build config
> only — there is no `ios/`, `android/`, or `macos/` app shell here. `bun run
> dev:ios`, `dev:android` and `dev:macos` build the JS bundle but have nothing
> to run it in. To see this app on a device or simulator:
>
> ```bash
> bunx vue-native create my-app   # scaffolds iOS + Android hosts
> ```
>
> Then copy `app/`, `vite.config.ts` and `env.d.ts` from this example over the
> scaffold's equivalents, run `bun run build` here, and open the generated
> project in Xcode or Android Studio. `vue-native create` does not scaffold a
> macOS shell yet.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput, VSlider, VVideo, VWebView, VScrollView, VSafeArea
- **Composables:** `useAudio`, `useDimensions`
- **Patterns:**
  - Video playback with transport controls
  - Audio playback and a volume slider driven by `useAudio`
  - Progress tracking and play/pause state
  - Viewport-derived sizing with `useDimensions`
  - An embedded `VWebView` with a URL bar

## Key Features

- Video player with transport controls
- Audio play/pause and progress tracking
- Volume slider
- Viewport-derived video sizing
- Embedded web view with a URL bar

## How to Run

```bash
cd examples/media-player
bun install
bun run dev:ios
# or: bun run dev:android
# or: bun run dev:macos
```

This directory contains Vue source only. Copy it into a generated project with
the matching native host before launching it.

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
