---
"@thelacanians/vue-native-cli": patch
---

Make Android Gradle failures diagnosable instead of opaque:

- `vue-native run android` and `vue-native build android` now capture Gradle's stderr and print the `* What went wrong:` block (SDK location not found, wrong Java version, unaccepted SDK licenses, Kotlin compile errors, ...) when the build exits non-zero, instead of only a bare exit code.
- When the Gradle wrapper exists but cannot be executed (spawn ENOENT — e.g. NixOS hosts without `/usr/bin/env`), the CLI now prints an actionable hint to run it through a shell.
