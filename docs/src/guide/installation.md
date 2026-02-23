# Installation

## Requirements

### iOS
- iOS 16.0+
- Xcode 15+
- Swift 5.9+

### Android
- Android 5.0+ (API 21+)
- Android Studio Hedgehog+
- Kotlin 1.9+

### Shared
- Node.js 18+ or [Bun](https://bun.sh)

## Create a new project

```bash
npx @thelacanians/vue-native-cli create my-app
cd my-app
```

The CLI scaffolds a full project with:

- Vue 3 app in `app/`
- iOS Xcode project in `ios/`
- Android Gradle project in `android/`
- Vite config with `@thelacanians/vue-native-vite-plugin`

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
