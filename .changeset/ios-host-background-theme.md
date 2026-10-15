---
"@thelacanians/vue-native-cli": patch
---

iOS: the area behind the safe area (status bar, home indicator) follows a background-only change of the app's root view, e.g. a light/dark theme switch, instead of waiting for the next layout pass.
