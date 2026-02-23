# @thelacanians/vue-native-vite-plugin

Vite plugin for building Vue Native applications. Configures Vite to output IIFE bundles compatible with native JavaScript runtimes (JavaScriptCore on iOS, V8 on Android).

## Install

```bash
npm install -D @thelacanians/vue-native-vite-plugin
# or
bun add -d @thelacanians/vue-native-vite-plugin
```

## Usage

```ts
// vite.config.ts
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vue-native-vite-plugin'

export default defineConfig({
  plugins: [vue(), vueNative()],
})
```

That's it. The plugin handles everything else automatically.

## What it does

1. **Aliases `'vue'` imports** to `@thelacanians/vue-native-runtime` so Vue SFCs use the native renderer instead of the DOM renderer
2. **Defines compile-time constants:**
   - `__DEV__` - `true` in development, `false` in production
   - `__PLATFORM__` - `'ios'` or `'android'`
3. **Configures IIFE output** - single self-executing bundle that works in JavaScriptCore/V8 (no ESM support in native runtimes)
4. **Sets the output filename** to `vue-native-bundle.js` in `dist/`

## Options

```ts
interface VueNativePluginOptions {
  /** Target platform: 'ios' or 'android'. Default: 'ios' */
  platform?: 'ios' | 'android'

  /** Global variable name for the IIFE bundle. Default: 'VueNativeApp' */
  globalName?: string
}
```

### Example with options

```ts
export default defineConfig({
  plugins: [
    vue(),
    vueNative({
      platform: 'android',
      globalName: 'MyApp',
    }),
  ],
})
```

## Peer dependencies

- `vite` ^6.0.0
- `@vitejs/plugin-vue` ^5.0.0

## License

MIT
