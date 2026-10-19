---
"@thelacanians/vue-native-cli": patch
"@thelacanians/vue-native-runtime": patch
---

`VTransition` can no longer leave an entering view stuck at its `enterFrom` style (e.g. invisible at opacity 0) when an animation call is lost, rejected or superseded: each element's enter chain carries a token, and a failed or cancelled enter snaps to `enterTo`. On iOS, `timing`/`spring` now apply `translateX`, `translateY`, `scale`, `scaleX` and `scaleY` (they were ignored, only opacity animated) and keep views interactive while animating. iOS audio: `stop()` and a newer `play()` cancel an in-flight remote download (a stopped clip no longer starts late; the superseded call resolves `{ cancelled: true }`), every failed `play()` emits `audio:error` so `isPlaying` resets, and `play(uri, { rate })` sets the playback speed (0.5 to 2.0, iOS only).
