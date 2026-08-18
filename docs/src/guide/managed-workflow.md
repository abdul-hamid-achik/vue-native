# Managed Workflow

Vue Native's managed workflow provides a low-config development experience similar to Expo. The CLI handles iOS and Android project scaffolding, native project generation, simulator management, and hot reload.

## Creating a Project

```bash
npx @thelacanians/vue-native-cli create my-app
cd my-app
bun install
```

### Templates

Use `--template` to start with a pre-configured layout:

```bash
# Blank app with a single screen (default)
vue-native create my-app --template blank

# Tab-based navigation with two screens
vue-native create my-app --template tabs

# Drawer navigation with sidebar menu
vue-native create my-app --template drawer
```

**Template contents:**

| Template | Includes |
|----------|----------|
| `blank` | Single Home screen with counter, stack navigation |
| `tabs` | Home + Settings screens, `createTabNavigator`, VTabBar |
| `drawer` | Home + About screens, `createDrawerNavigator`, sidebar menu |

All templates include:
- Complete iOS Xcode project (`ios/`) with XcodeGen spec
- Complete Android Gradle project (`android/`) with Kotlin
- Vite configuration with Vue Native plugin
- TypeScript configuration
- `vue-native.config.ts` configuration file
- `.gitignore` with common exclusions

::: note macOS
The CLI can run and build an existing macOS Xcode project, but `vue-native create` does not scaffold a macOS app shell yet. Use the [macOS Setup](/macos/setup.md) guide to add that target manually.
:::

## Project Configuration

Configure your app with `vue-native.config.ts` in the project root:

```ts
import { defineConfig } from '@thelacanians/vue-native-cli'

export default defineConfig({
  name: 'MyApp',
  bundleId: 'com.example.myapp',
  version: '1.0.0',
  ios: {
    deploymentTarget: '16.0',
  },
  android: {
    minSdk: 21,
    targetSdk: 35,
  },
  macos: {
    deploymentTarget: '15.0',
  },
})
```

The CLI validates this file on `dev`, `run`, `build`, `inspect`, and `doctor`.
`bundleId`, `ios.scheme`, `macos.scheme`, and `android.packageName` provide
launch/build defaults. Native deployment targets are written into the generated
Xcode/Gradle files at scaffold time; if you change those values later, update
the native project too.

### Configuration Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | Yes | App display name |
| `bundleId` | `string` | Yes | Reverse-domain identifier (e.g. `com.example.myapp`) |
| `version` | `string` | Yes | Semantic version string |
| `ios.deploymentTarget` | `string` | No | Minimum iOS version (default: `"16.0"`) |
| `ios.scheme` | `string` | No | Xcode scheme name (defaults to sanitized `name`) |
| `android.minSdk` | `number` | No | Minimum Android SDK (default: `21`) |
| `android.targetSdk` | `number` | No | Target Android SDK (default: `35`) |
| `android.packageName` | `string` | No | Android package (defaults to `bundleId`) |
| `macos.deploymentTarget` | `string` | No | Minimum macOS version (default: `"15.0"`) |
| `macos.scheme` | `string` | No | Xcode scheme name (defaults to sanitized `name`) |
| `plugins` | `string[]` | No | Reserved metadata for future plugin automation; plugins are not installed automatically |

## Development Server

```bash
vue-native dev
```

Starts the Vite build watcher and WebSocket hot reload server. The app on your simulator or device will reload automatically when you save changes.

### Options

| Flag | Description |
|------|-------------|
| `-p, --port <port>` | WebSocket port (default: `8174`) |
| `--platform <platform>` | Compile for `ios`, `android`, or `macos` |
| `--ios` | Auto-detect and boot iOS Simulator |
| `--android` | Auto-detect Android emulator |
| `--simulator <name>` | Specify iOS Simulator name (e.g. `"iPhone 16"`) |

### Auto-launching Simulators

```bash
# Auto-detect and boot an iOS simulator
vue-native dev --ios

# Boot a specific simulator
vue-native dev --ios --simulator "iPhone 16 Pro"

# Detect Android emulator
vue-native dev --android

# Build a macOS development bundle
vue-native dev --platform macos
```

Each development bundle has one compile-time platform target. Run separate dev commands when switching targets; `--ios --android` is rejected. A `--platform` value must also match any `--ios` or `--android` launch flag.

When using `--ios`, the CLI will:
1. Query available simulators via `xcrun simctl list`
2. Boot an available iPhone simulator (or the specified one)
3. Open Simulator.app
4. Start the hot reload server

When using `--android`, the CLI will check for connected devices/emulators via `adb devices`.

## Building and Running

```bash
# Build JS bundle and run on iOS simulator
vue-native run ios

# Build and run on Android emulator
vue-native run android

# Run on a physical device
vue-native run ios --device
```

### Run Options

| Flag | Description |
|------|-------------|
| `--device` | Run on physical device |
| `--scheme <name>` | Xcode scheme to build |
| `--simulator <name>` | Simulator name (default: `"iPhone 16"`) |
| `--bundle-id <id>` | App bundle identifier |
| `--package <name>` | Android package (default: `com.vuenative.app`) |
| `--activity <name>` | Android activity (default: `.MainActivity`) |
| `--bundle-only` | Stop after the JavaScript bundle. Missing native projects or `.app` / APK / AAB products otherwise fail the command. |

## Project Structure

After `vue-native create`, your project looks like:

```
my-app/
  app/                   # Vue 3 source code
    main.ts              # Entry point
    App.vue              # Root component
    pages/               # Screen components
      Home.vue
  ios/                   # iOS native project
    project.yml          # XcodeGen specification
    Sources/
      AppDelegate.swift
      SceneDelegate.swift
      Info.plist
  android/               # Android native project
    app/
      build.gradle.kts
      src/main/
        AndroidManifest.xml
        kotlin/.../MainActivity.kt
    build.gradle.kts
    settings.gradle.kts
  dist/                  # Built JS bundle (generated)
  vue-native.config.ts   # App configuration
  vite.config.ts         # Vite build config
  package.json
  tsconfig.json
```

## Typical Workflow

1. **Create** a project: `vue-native create my-app --template tabs`
2. **Install** dependencies: `cd my-app && bun install`
3. **Develop** with hot reload: `vue-native dev --ios`
4. **Edit** Vue components in `app/` -- changes appear instantly
5. **Diagnose** the project: `vue-native doctor` then `vue-native inspect --json`
6. **Build** for testing: `vue-native run ios` or `vue-native run android`
7. **Release** via Xcode (iOS) or Gradle (Android)

## Diagnostic commands

Every command below accepts `--json` with `schemaVersion: 1` for agents and CI.

```bash
vue-native doctor --json
vue-native inspect --json
vue-native capabilities --json
```

| Command | What it reports | Exit |
|---------|-----------------|------|
| `doctor` | Toolchain and native-project health (`bun`, config, `ios/` / `android/` / `macos/`, `xcodebuild`, Java, Android SDK). | `1` when a check at level `error` fails |
| `inspect` | Snapshot of the current project: resolved config, native hosts, `dist/vue-native-bundle.js`, generated-module dirs. | `0` (informational) |
| `capabilities` | Framework contract: Vue cohort, 40 built-in components, native modules with per-platform `full` / `unsupported`, and known limitations. | `0` (informational) |

`inspect` looks for config as `vue-native.config.{ts,js,mjs}`. A missing config is reported as `config.found: false`; a parse/validation error is `config.error`.

`capabilities` is a first manifest, not a codegen source of truth. Platform omissions match the native-module contract checker (for example `Http` is Android-only; `Menu` / `Window` / `FileDialog` / `DragDrop` are macOS-only).

Host-boot and device smoke for this repository live in [Testing](./testing.md#host-boot-and-device-smoke).

### `vue-native generate`

Regenerates Swift / Kotlin / TypeScript from `<native>` blocks. Parse and validation errors fail the command (`ConfigError`). Files are written, then stale generated output is pruned — last-known-good files are not deleted before the new write succeeds.

```bash
vue-native generate
vue-native generate --watch
```
