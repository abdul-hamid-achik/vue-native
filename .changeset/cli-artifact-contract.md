---
"@thelacanians/vue-native-cli": patch
---

`vue-native build` and `vue-native run` now fail when the native project or the produced `.app` / APK / AAB / xcarchive is missing, instead of exiting 0 after only the JS bundle. Pass `--bundle-only` to stop after `dist/vue-native-bundle.js`. Apple product lookup is shared, newest-DerivedData-first, and scheme-scoped on iOS and macOS.
