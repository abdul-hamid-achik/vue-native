# Managed Workflow

Vue Native's managed workflow provides a zero-config development experience similar to Expo. The CLI handles project scaffolding, native project generation, simulator management, and hot reload.

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
    minSdk: 24,
    targetSdk: 35,
  },
})
```

### Configuration Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | Yes | App display name |
| `bundleId` | `string` | Yes | Reverse-domain identifier (e.g. `com.example.myapp`) |
| `version` | `string` | Yes | Semantic version string |
| `ios.deploymentTarget` | `string` | No | Minimum iOS version (default: `"16.0"`) |
| `ios.scheme` | `string` | No | Xcode scheme name (defaults to sanitized `name`) |
| `android.minSdk` | `number` | No | Minimum Android SDK (default: `24`) |
| `android.targetSdk` | `number` | No | Target Android SDK (default: `35`) |
| `android.packageName` | `string` | No | Android package (defaults to `bundleId`) |
| `plugins` | `string[]` | No | Vue Native plugins to include |

## Development Server

```bash
vue-native dev
```

Starts the Vite build watcher and WebSocket hot reload server. The app on your simulator or device will reload automatically when you save changes.

### Options

| Flag | Description |
|------|-------------|
| `-p, --port <port>` | WebSocket port (default: `8174`) |
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

# Both platforms
vue-native dev --ios --android
```

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
5. **Build** for testing: `vue-native run ios` or `vue-native run android`
6. **Release** via Xcode (iOS) or Gradle (Android)
