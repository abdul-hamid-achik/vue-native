---
"@thelacanians/vue-native-runtime": patch
"@thelacanians/vue-native-navigation": patch
"@thelacanians/vue-native-vite-plugin": patch
"@thelacanians/vue-native-cli": patch
"@thelacanians/vue-native-sfc-parser": patch
---

Keep every workspace and generated app on one exact Vue dependency cohort,
validate physical runtime duplication, and exercise Vue 3.6 compatibility in a
non-publishing CI lane. Reject unsupported Vapor SFC modes early and keep the
native renderer isolated from DOM renderer aliases.
