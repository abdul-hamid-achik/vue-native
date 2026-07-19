# Building Native Apps

## CLI Build Commands

The CLI provides `vue-native build` for creating debug or release artifacts. It automatically bundles the JS before building the native project.

```bash
# Build iOS release
vue-native build ios

# Build Android APK
vue-native build android

# Build Android App Bundle (.aab) for Play Store
vue-native build android --aab
```

### Build Options

| Flag | Description |
|------|-------------|
| `--mode <mode>` | Native build mode: `debug` or `release` (default: `release`) |
| `--output <path>` | Output directory for the build artifact (default: `./build`) |
| `--scheme <scheme>` | Xcode scheme to build (iOS and macOS) |
| `--aab` | Build Android App Bundle instead of APK (Android only) |

### Examples

```bash
# Release build with custom output directory
vue-native build ios --output ./artifacts

# Debug build
vue-native build ios --mode debug

# Android debug APK
vue-native build android --mode debug

# Specific Xcode scheme
vue-native build ios --scheme MyApp-Staging

# Android App Bundle for Play Store
vue-native build android --aab --output ./release
```

The CLI auto-bundles the JS before running the native build — you do not need to run `bun run build` separately.

## Manual Build

If you prefer to build manually without the CLI, you can bundle the JS first:

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

The resource entry in `project.yml` automatically copies `dist/vue-native-bundle.js` into the app bundle at build time. The generated project links the bundled local `native/ios/VueNativeCore` Swift package so `<native>` block output is compiled into the application.

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

Every push to `main` and every pull request runs four parallel jobs in [GitHub Actions](https://github.com/abdul-hamid-achik/vue-native/actions):

| Job | Runner | Steps |
|-----|--------|-------|
| **TypeScript** | ubuntu-latest | lint → typecheck → native-module contract check → build → test → Knip → hook configuration validation |
| **Swift (iOS)** | macos-14 | SwiftLint → in-repo and consumer-facing builds → XCTest on an available iPhone simulator |
| **Swift (macOS)** | macos-15 | build and test the shared package, root macOS product, and macOS package |
| **Kotlin** | ubuntu-latest | ktlint → release build → JUnit + Robolectric |

### Running the full pipeline locally

```bash
# TypeScript (the same gate is installed as the Lefthook pre-push hook)
bun run check:ts

# iOS
(cd native/ios && swiftlint lint)
(
  cd native/ios/VueNativeCore
  xcodebuild test \
    -scheme VueNativeCore \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
    -skipPackagePluginValidation
)

# Shared Swift package
(
  cd native/shared/VueNativeShared
  swift build
  swift test
)

# macOS
(
  cd native/macos/VueNativeMacOS
  swift build
  swift test
)

# Android
(
  cd native/android
  ./gradlew :VueNativeCore:ktlintCheck :VueNativeCore:testReleaseUnitTest
)
```

### Publishing

Pushing to `main` with a pending Changeset, or manually dispatching the workflow on `main`, triggers publishing after the TypeScript and native release gates pass:

1. **npm** — publishes every versioned public workspace package selected by Changesets (runtime, navigation, Vite plugin, CLI, codegen, and SFC parser)
2. **Swift Package** — validated via xcodebuild (SPM resolves directly from the git tag)
3. **Android Maven** — publishes `com.vuenative:core` to GitHub Packages

Runtime, navigation, the Vite plugin, and the CLI form the fixed framework
version group. SFC parser and codegen are versioned independently, so a release
can legitimately contain framework `0.7.x` packages and compiler `0.6.x`
packages. The annotated `vX.Y.Z` tag identifies the framework/native release;
each newly published npm artifact also receives its own annotated
`<package-name>@<package-version>` tag.
