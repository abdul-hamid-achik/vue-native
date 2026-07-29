---
"@thelacanians/vue-native-runtime": minor
---

Variable-height list virtualization and native-driven pinch/rotate gestures.

- **`VFlatList` variable heights:** `itemHeight` is now optional. Omit it and pass `estimatedItemHeight` for variable-height lists — the native side measures each item's real height and reports it via an `itemLayout` event, and the list positions items by their cumulative measured heights (binary-search windowing). Fixed-height lists (`itemHeight`) keep the fast path.
- **Native-driven pinch/rotate gestures:** `useGesture`'s `nativeDrive` now also drives pinch (scale) and rotate transforms on the native UI thread (in addition to pan), so gesture-driven animations run without a per-frame JS round-trip. Backed by native gesture handling on iOS/Android/macOS (ships with the tag).
