---
'@thelacanians/vue-native-cli': patch
---

Android projects created with `vue-native create` build again.

Since 0.21.0 the vendored `:VueNativeCore` module reads its dependency
versions from `native/android/gradle/libs.versions.toml`, but the generated
`android/settings.gradle.kts` never registered that catalog, so every
scaffolded Android build failed with "Unresolved reference: libs". New
projects register it, and `vue-native upgrade` adds it to existing ones.
Hosts that do not upgrade can add this inside `dependencyResolutionManagement`:

```kotlin
versionCatalogs {
    create("libs") {
        from(files("../native/android/gradle/libs.versions.toml"))
    }
}
```
