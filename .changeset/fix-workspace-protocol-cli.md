---
"@thelacanians/vue-native-sfc-parser": patch
"@thelacanians/vue-native-codegen": patch
"@thelacanians/vue-native-vite-plugin": patch
"@thelacanians/vue-native-cli": patch
---

Fix `workspace:*` protocol that caused `npm error Unsupported URL Type "workspace:"` when installing packages globally. Replaced with `^0.0.1` semver ranges for internal dependencies (sfc-parser, codegen) that are bundled into dist at build time.
