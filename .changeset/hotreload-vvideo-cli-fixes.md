---
"@thelacanians/vue-native-runtime": patch
"@thelacanians/vue-native-cli": patch
---

**Runtime:**

- `VToolbar`, `VSplitView`, and `VOutlineView` (macOS-only components) now log a development warning when used on iOS/Android, where they render nothing — instead of failing silently.

**CLI:**

- `vue-native run ios` now auto-detects a simulator when `--simulator` is omitted (prefers an already-booted simulator, then the first available iPhone), instead of assuming a hardcoded "iPhone 16" that may not exist.

**Native (ships with the tag):**

- iOS/macOS hot reload now reconnects indefinitely with exponential backoff (1s→30s cap) instead of giving up after ~10 attempts when the dev server is briefly unavailable.
- iOS/Android `VVideo` now fires `play`/`pause` events on playback state changes (previously accepted but never emitted).
- Android event/module payloads are always serialized as valid JSON (removed a raw `toString()` concatenation that was a latent JS-injection sink).
