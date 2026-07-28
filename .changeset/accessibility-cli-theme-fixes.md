---
"@thelacanians/vue-native-runtime": minor
"@thelacanians/vue-native-cli": patch
---

**Runtime:**

- New `useAccessibility()` composable: `announce(message)` makes the screen reader (VoiceOver/TalkBack) speak a status message without moving focus, and `setFocus(target)` moves accessibility focus to a view (WCAG 4.1.3 / 2.4.3). Backed by a native `Accessibility` module on iOS/Android/macOS (ships with the tag).
- `createTheme`'s `ThemeProvider` accepts a `followSystem` prop that syncs the color scheme with the system appearance (via `useColorScheme`) and updates automatically when the OS switches light/dark mode.
- `useBackHandler` no longer calls the Android-only `BackHandler.exitApp` on iOS/macOS (avoids a guaranteed failure when the back event is dispatched programmatically there).

**CLI:**

- Fixed `vue-native run ios` selecting the wrong app from DerivedData: projects are now sorted by modification time (most recent first) instead of reversed alphabetical order.
- `vue-native dev --port` now validates the port (integer in 1–65535) and fails with a clear error instead of crashing obscurely.
