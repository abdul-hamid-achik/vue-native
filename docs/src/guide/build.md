# Building for Release

## Build the JS bundle

```bash
bun run build
```

This produces an optimized, minified `dist/vue-native-bundle.js`.

## iOS

1. Build the bundle: `bun run build`
2. Open `ios/` in Xcode
3. Select your scheme and a real device or "Any iOS Device"
4. **Product → Archive**
5. In the Organizer, click **Distribute App** and follow the steps

The build script in `project.yml` automatically copies `dist/vue-native-bundle.js` into the app bundle at build time.

## Android

1. Build the bundle: `bun run build`
2. Copy `dist/vue-native-bundle.js` to `android/app/src/main/assets/`
3. In Android Studio: **Build → Generate Signed Bundle / APK**
4. Choose **Android App Bundle** for Play Store, or **APK** for direct distribution

::: tip Automate asset copying
Add a Gradle task to your `android/app/build.gradle.kts` to copy the bundle automatically:

```kotlin
tasks.register<Copy>("copyJsBundle") {
    from("../../dist/vue-native-bundle.js")
    into("src/main/assets")
}
tasks.named("preBuild") { dependsOn("copyJsBundle") }
```
:::
