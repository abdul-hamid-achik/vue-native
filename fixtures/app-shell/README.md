# App-shell fixture

Deterministic JavaScript that a Vue Native host can evaluate without Vite or Vue.

`vue-native-bundle.js` calls `__VN_flushOperations` and mounts a `VView` /
`VText` tree with stable accessibility labels:

| Label | Meaning |
| --- | --- |
| `app-shell-root` | Root view attached by `setRootView` |
| `app-shell-label` | Child text, content `app-shell-ok` |

This is host-boot coverage, not a physical-device smoke. Device evidence stays
separate.

Android Robolectric cannot load J2V8's Android native library. The host test
boots `VueNativeActivity` and evaluates the same IIFE with Rhino, binding
`__VN_flushOperations` to the live `NativeBridge`. macOS (and iOS when a
simulator exists) evaluate the file through JavaScriptCore.

The same file is loaded by:

- Android `AppShellSmokeTest` (Robolectric `VueNativeActivity`)
- iOS `AppShellSmokeTests` (`VueNativeViewController`)
- macOS `AppShellSmokeTests` (`VueNativeWindowController`)
- `bun run smoke:app-shell` (receipt in `artifacts/app-shell-smoke.json`)
