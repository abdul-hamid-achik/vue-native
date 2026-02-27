# Media Player Example

Demonstrates video playback, audio controls, and embedded web content.

## Components Used

- **VVideo** — Video playback with custom controls (AVPlayer / MediaPlayer)
- **VWebView** — Embedded web browser with URL bar
- **VSlider** — Volume control and seek
- **VPressable** — Tap targets for player controls

## Composables Used

- **useAudio** — Audio playback: play, pause, resume, stop, seek, volume
- **useDimensions** — Responsive video sizing based on screen width

## Features

- Video player with play/pause/mute controls and progress display
- Audio player with track list, progress bar, prev/next, volume slider
- Embedded web browser (VWebView) with URL input
- Dark theme media UI
- Tab-based navigation between Video, Audio, and Web views

## Running

```bash
bun run dev    # Watch mode
bun run build  # Production build
```
