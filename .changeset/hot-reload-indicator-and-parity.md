---
"@thelacanians/vue-native-runtime": minor
"@thelacanians/vue-native-cli": minor
---

Developer-experience and platform-parity round: debug builds with a dev server configured now show a small hot-reload connection badge (orange "Connecting…", red "Disconnected — check `vue-native dev`" after several failed attempts, green "Connected" that auto-hides) on iOS, Android, and macOS; `useCamera().scanQRCode()` works on Android via a CameraX scanning screen backed by ML Kit's bundled barcode model with iOS-matching payloads and `type` strings; `usePermissions()` supports `'contacts'` and `'calendar'` on all platforms (the macOS module also no longer collapses `restricted` into `denied`); `VRefreshControl`'s `style` prop actually reaches the native view; and macOS scroll views finally lay out their document content through the shared layout engine (previously the recursive layout pass never descended past `NSClipView`, leaving scroll content at zero size — `flexGrow` directly inside scroll content remains a documented limitation).
