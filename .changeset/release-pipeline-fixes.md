---
"@thelacanians/vue-native-cli": patch
---

Release pipeline fixes:

- CLI `prebuild` no longer copies Swift/Gradle build caches into the package (uses `rsync` with targeted excludes; published tarball ~361 KB instead of multi-GB).
- `vue-native --version` now reads the real version from package.json (was hard-coded to 0.1.0).
- Android Maven publication and scaffolded SPM/Gradle dep coordinates now derive from `packages/runtime/package.json`, keeping the native artifact version in sync with the JS runtime release.
- Added a root `Package.swift` so `https://github.com/abdul-hamid-achik/vue-native` resolves cleanly via SPM.
- Publish workflow builds *after* `changeset version` so dist artifacts match the version they ship with.
