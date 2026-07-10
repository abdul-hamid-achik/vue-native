# @thelacanians/vue-native-cli

CLI for creating and running Vue Native apps on iOS and Android.

## Install

```bash
npm install -g @thelacanians/vue-native-cli
# or
bun install -g @thelacanians/vue-native-cli
```

## Commands

### `vue-native create <name>`

Scaffold a new Vue Native project with everything you need:

```bash
vue-native create my-app
cd my-app
bun install
```

Generated project structure:

```
my-app/
  app/
    main.ts          # Entry point
    App.vue          # Root component
    generated/       # TypeScript wrappers generated from <native> blocks
    pages/
      Home.vue       # Home screen
  ios/
    Sources/         # Swift source files
    project.yml      # XcodeGen spec
  android/
    app/             # Android app module
    build.gradle.kts
    settings.gradle.kts
    gradlew          # Bundled Gradle wrapper script
    gradle/wrapper/  # Wrapper properties and JAR
  native/            # Bundled native runtime source
    android/VueNativeCore/     # Linked locally as :VueNativeCore
    ios/VueNativeCore/         # Linked as a local Swift package
    shared/VueNativeShared/    # Shared Apple runtime
  vite.config.ts
  package.json
  tsconfig.json
```

The scaffold is self-contained: Android uses the bundled Gradle wrapper and
local `:VueNativeCore` module, while iOS uses the bundled local Swift package.
This also ensures code generated from `<native>` blocks is compiled into both
apps. `vue-native run ios` generates the Xcode project from `project.yml` when
needed; install XcodeGen with `brew install xcodegen`.

### `vue-native dev`

Start the dev server with hot reload:

```bash
vue-native dev
vue-native dev --port 9000  # Custom port
```

Runs Vite in watch mode and starts a WebSocket server on port 8174 (default). When you save a file, the updated bundle is pushed to all connected iOS/Android apps instantly.

### `vue-native run <platform>`

Build and launch the app on a simulator/emulator:

```bash
# iOS
vue-native run ios
vue-native run ios --simulator "iPhone 16 Pro"
vue-native run ios --device

# Android
vue-native run android
```

#### iOS options

| Option | Default | Description |
|--------|---------|-------------|
| `--simulator <name>` | `iPhone 16` | Simulator device name |
| `--device` | `false` | Build for physical device |
| `--scheme <name>` | auto-detect | Xcode scheme |
| `--bundle-id <id>` | auto-detect | App bundle identifier |

#### Android options

| Option | Default | Description |
|--------|---------|-------------|
| `--package <name>` | auto-detect | Override the application ID used to launch the app |
| `--activity <name>` | `.MainActivity` | Launch activity |

Before an Android run or native build, the CLI copies
`dist/vue-native-bundle.js` into the app's assets directory automatically.

### `vue-native build <platform>`

Create an iOS, Android, or macOS artifact after bundling the JavaScript:

```bash
vue-native build ios
vue-native build android --aab
vue-native build macos
vue-native build android --mode debug
```

`--mode` accepts `debug` or `release` (the default). Use `--output` to choose
the artifact directory, `--scheme` for an iOS or macOS Xcode scheme, and
`--aab` to create an Android App Bundle instead of an APK.

## Development workflow

```bash
# Terminal 1: Start dev server
vue-native dev

# Terminal 2: Build and run on iOS simulator
vue-native run ios

# Edit your Vue files - changes hot reload automatically
```

## License

MIT
