---
"@thelacanians/vue-native-cli": minor
"@thelacanians/vue-native-codegen": patch
"@thelacanians/vue-native-vite-plugin": minor
---

`vue-native generate` treats parse errors as failures and commits generated files atomically (write, then prune stale output). `vue-native doctor [--json]` reports toolchain and native-project health. Scaffolded apps no longer enable DOM libs, pin Gradle 8.6 to match the bundled wrapper, and include a `macos` config section.
