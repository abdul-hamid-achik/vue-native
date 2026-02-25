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

## CI Pipeline

Every push to `main` and every pull request runs three parallel jobs in [GitHub Actions](https://github.com/abdul-hamid-achik/vue-native/actions):

| Job | Runner | Steps |
|-----|--------|-------|
| **TypeScript** | ubuntu-latest | lint → typecheck → build → test → dead code check (knip) |
| **Swift** | macos-14 | SwiftLint → build VueNativeCore → XCTest (114 tests on iPhone simulator) |
| **Kotlin** | ubuntu-latest | ktlint → build VueNativeCore → JUnit + Robolectric (83 tests) |

### Running the full pipeline locally

```bash
# TypeScript
bun run lint && bun run typecheck && bun run build && bun run test

# iOS
cd native/ios && swiftlint lint
xcodebuild test \
  -scheme VueNativeCore \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  -skipPackagePluginValidation

# Android
cd native/android
./gradlew :VueNativeCore:ktlintCheck :VueNativeCore:testReleaseUnitTest
```

### Publishing

Pushing a git tag matching `v*` (e.g., `v0.4.13`) triggers the publish workflow:

1. **npm** — publishes `@thelacanians/vue-native-runtime`, `@thelacanians/vue-native-navigation`, `@thelacanians/vue-native-vite-plugin`, and `@thelacanians/vue-native-cli` to npm
2. **Swift Package** — validated via xcodebuild (SPM resolves directly from the git tag)
3. **Android Maven** — publishes `com.vuenative:core` to GitHub Packages
