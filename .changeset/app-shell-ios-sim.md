---
"@thelacanians/vue-native-cli": patch
---

`bun run smoke:app-shell` now probes simulators and physical devices, runs the iOS host-boot fixture on an available Simulator, and records skip reasons when phones are paired but disconnected. `NotificationsModule` no longer crashes XCTest by touching `UNUserNotificationCenter` in the xctest agent. `bun run ios:ensure-simulator` downloads the iOS runtime when it is missing.
