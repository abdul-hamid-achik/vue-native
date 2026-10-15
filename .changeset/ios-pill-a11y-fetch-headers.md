---
"@thelacanians/vue-native-cli": patch
---

iOS native fixes: pill corner radii (`borderRadius: 999`) no longer hide the view, the area behind the safe area takes the app's background instead of black, unset accessibility props no longer hide whole subtrees from VoiceOver and UI tests, and `fetch` responses expose a `Headers`-like `response.headers` with `get()` (also on macOS).
