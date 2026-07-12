# Gestures Example

This example demonstrates gesture handling in Vue Native apps using `useGesture`.

## Features Demonstrated

- **Pan gesture**: Drag a view around the screen
- **Pinch gesture**: Zoom in/out with two fingers
- **Rotate gesture**: Rotate a view with two fingers
- **Swipe gestures**: Detect left/right/up/down swipes
- **Double tap**: Handle double-tap interactions
- **Force touch**: 3D Touch / pressure-sensitive interactions (iOS/macOS)
- **Composed gestures**: Multiple simultaneous gestures

## Running

### iOS

```bash
cd examples/gestures
bun install
bun run dev:ios
```

### Android

```bash
cd examples/gestures
bun install
bun run dev:android
```

### macOS

```bash
cd examples/gestures
bun install
bun run dev:macos
```

This directory intentionally contains the cross-platform Vue source only. It
does not contain the `ios/`, `android/`, or `macos/` hosts referenced by older
versions of this README. Copy the source into a generated project with the
matching native host to run it.
