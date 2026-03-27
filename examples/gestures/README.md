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
bun run dev  # Terminal 1: Watch and rebuild JS bundle

# Open ios/GesturesApp.xcworkspace in Xcode and run
```

### Android

```bash
cd examples/gestures
bun install
bun run dev  # Terminal 1: Watch and rebuild JS bundle

# Open android/ in Android Studio and run
```

### macOS

```bash
cd examples/gestures
bun install
bun run dev  # Terminal 1: Watch and rebuild JS bundle

# Open macos/GesturesApp.xcworkspace in Xcode and run
```