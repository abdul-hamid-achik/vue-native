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
    pages/
      Home.vue       # Home screen
  ios/
    Sources/         # Swift source files
    project.yml      # XcodeGen spec
  android/
    app/             # Android app module
    build.gradle.kts
  vite.config.ts
  package.json
  tsconfig.json
```

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
| `--package <name>` | `com.vuenative.app` | Android package name |
| `--activity <name>` | `.MainActivity` | Launch activity |

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
