---
"@thelacanians/vue-native-runtime": minor
---

List virtualization and native-driven gestures.

- **`VList` virtualization:** large lists now render only the visible window plus a buffer (`windowSize` prop, default 10) with spacer views preserving scroll content size, reducing memory from O(n) to O(window). Small lists render everything as before.
- **Native-driven pan gestures:** `useGesture(ref, { pan: { nativeDrive: true } })` makes the native side apply the pan translation directly to the view's transform on the UI thread (no JS round-trip per frame), for smooth dragging. The `pan` callback still fires for state/`ended` handling. Backed by native gesture handling on iOS/Android/macOS (ships with the tag).
