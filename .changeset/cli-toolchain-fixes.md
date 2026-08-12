---
"@thelacanians/vue-native-cli": patch
"@thelacanians/vue-native-codegen": patch
"@thelacanians/vue-native-vite-plugin": patch
---

Toolchain fixes: `run android`/`build android` now work on Windows (the CLI resolves `gradlew.bat` with a shell instead of spawning the POSIX `./gradlew` script); `vue-native dev` fails fast with an actionable message when Bun is missing instead of hanging on "Waiting for app to connect..."; iOS/macOS commands on non-macOS hosts explain that Xcode on macOS is required instead of suggesting `brew install xcodegen`; the `<native>` block validator accepts `NativeModule` anywhere in a class's conformance list (e.g. `class LocationModule: NSObject, NativeModule` — previously rejected with a misleading error); the Vite plugin no longer re-scans nested `node_modules` trees on every hot-reload edit; scaffolded `.gitignore` excludes the XcodeGen-generated `ios/*.xcodeproj`/`*.xcworkspace`; and `run`/`build` warn when `vue-native.config.ts` deployment targets have drifted from the native project files (which are the source of truth after scaffolding).
