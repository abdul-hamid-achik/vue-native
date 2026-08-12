---
"@thelacanians/vue-native-cli": patch
---

macOS `VScrollView` pins overlay scrollers (matching the iOS-style indicators used everywhere else), so layout no longer varies by host input devices — legacy inset scrollers reserved ~15pt of content width when a mouse was plugged in.
