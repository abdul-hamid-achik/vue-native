---
'@thelacanians/vue-native-cli': patch
---

`testID` reaches native views, and VCheckbox speaks on iOS.

- `testID` was declared on five components and dropped by every platform. It now
  sets `accessibilityIdentifier` on iOS and macOS and the node's
  `viewIdResourceName` on Android, so XCUITest, UiAutomator and Maestro can find
  views.
- iOS `VCheckbox` is one VoiceOver element with a button trait, its label, a
  checked/unchecked value, and a not-enabled trait while disabled.
- macOS maps `accessibilityRole: 'adjustable'` to a slider, as iOS and Android do.
