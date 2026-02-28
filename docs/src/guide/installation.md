# Installation

## Requirements

### iOS
- iOS 16.0+
- Xcode 15+
- Swift 5.9+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Android
- Android 7.0+ (API 24+)
- Android Studio Ladybug+
- Android SDK API 35
- JDK 17 (bundled with Android Studio)

### macOS
- macOS 13.0 (Ventura)+
- Xcode 15+
- Swift 5.9+

### Shared
- Node.js 18+ or [Bun](https://bun.sh)

For full platform setup instructions (emulator/simulator configuration, environment variables, etc.), see the [iOS Setup](/ios/setup.md), [Android Setup](/android/setup.md), and [macOS Setup](/macos/setup) guides.

## Create a new project (recommended)

The fastest way to get started is with the managed workflow. The CLI scaffolds a complete project with native projects for all platforms:

```bash
npx @thelacanians/vue-native-cli create my-app
cd my-app
bun install
vue-native dev --ios
```

You can also choose a template or target specific platforms:

```bash
# Tab-based navigation
vue-native create my-app --template tabs

# Drawer navigation
vue-native create my-app --template drawer

# Include macOS target
vue-native create my-app --platforms ios,android,macos
```

The CLI scaffolds a full project with:

- Vue 3 app in `app/`
- iOS Xcode project in `ios/`
- macOS Xcode project in `macos/` (when `--platforms` includes `macos`)
- Android Gradle project in `android/`
- Vite config with `@thelacanians/vue-native-vite-plugin`
- `vue-native.config.ts` for app configuration

See the [Managed Workflow](./managed-workflow.md) guide for the full configuration reference and available CLI commands.

## Manual setup

If you prefer to set up manually, install the packages:

```bash
bun add @thelacanians/vue-native-runtime
bun add -d @thelacanians/vue-native-vite-plugin @vitejs/plugin-vue vite
```

Then configure Vite:

```ts
// vite.config.ts
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vue-native-vite-plugin'

export default defineConfig({
  plugins: [vue(), vueNative()],
})
```
