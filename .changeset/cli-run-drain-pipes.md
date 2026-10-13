---
'@thelacanians/vue-native-cli': patch
---

`vue-native run ios` and `run macos` no longer hang during the build.

The CLI started xcodebuild with piped output and read only stderr. Once
xcodebuild had written about 64 KB to stdout, which a first build does, it
blocked on the full pipe and the command waited forever with no CPU use.
Output streams without a reader are now drained.
