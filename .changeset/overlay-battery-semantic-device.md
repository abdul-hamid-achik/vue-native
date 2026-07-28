---
"@thelacanians/vue-native-runtime": minor
"@thelacanians/vue-native-cli": minor
---

**Runtime:**

- New `useBattery()` composable: reactive battery `level` (0..1) and `isCharging`, with `isSupported` false on devices without a battery (desktop Mac). Polls every 60s by default (`pollInterval` configurable).
- `createTheme`'s `<ThemeProvider>` accepts a `persist` prop (boolean or custom storage key) that saves the color scheme via AsyncStorage on change and restores it on startup.
- The style engine now recognizes semantic color names (`background`, `label`, `secondaryLabel`, `tertiaryLabel`, `separator`, `systemBlue`, `systemRed`, `systemGreen`, `systemOrange`, `systemGray`) that resolve to platform dynamic colors (auto light/dark).

**CLI:**

- `vue-native run ios --device` now installs and launches the app on a connected physical device via `xcrun devicectl` (Xcode 15+), with a `--device-id <udid>` flag to pick a device. Falls back to a clear error pointing to Xcode/`ios-deploy` when `devicectl` is unavailable.

**Native (ships with the tag):**

- iOS/Android/macOS: the JS error overlay is now structured — bold message, monospace scrollable stack trace, the failing component name, and a Reload button.
- iOS/Android: new `Battery` native module backing `useBattery`.
- iOS/Android/macOS: semantic color resolution to platform dynamic colors.
- iOS: CJK composition events (`compositionstart`/`compositionend`) best-effort from the IME.
