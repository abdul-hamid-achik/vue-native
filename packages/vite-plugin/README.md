# @thelacanians/vue-native-vite-plugin

Vite plugin for building Vue Native applications. Configures Vite to output IIFE bundles compatible with native JavaScript runtimes (JavaScriptCore on iOS and macOS, V8 on Android).

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
   - `__PLATFORM__` - `'ios'`, `'android'`, or `'macos'`
3. **Configures IIFE output** - single self-executing bundle that works in JavaScriptCore/V8 (no ESM support in native runtimes)
4. **Sets the output filename** to `vue-native-bundle.js` in `dist/`

## Options

```ts
interface VueNativePluginOptions {
  /** Target platform when VUE_NATIVE_PLATFORM is not present. */
  platform?: 'ios' | 'android' | 'macos'

  /** Global variable name for the IIFE bundle. Default: 'VueNativeApp' */
  globalName?: string
}
```

### Platform resolution

The plugin resolves one compile-time target for each bundle:

1. `VUE_NATIVE_PLATFORM`, when present
2. The explicit `platform` option
3. `'ios'` when neither value is present

`VUE_NATIVE_PLATFORM` must be exactly `ios`, `android`, or `macos`; an invalid present value fails the build even when the plugin has an explicit option. The Vue Native CLI supplies this variable for `run`, `build`, and targeted `dev` commands, making its selected target authoritative over an existing hardcoded plugin option.

Set `VUE_NATIVE_PLATFORM` in the shell that starts Vite. Do not rely on a Vite `.env` file for this setting because Vite evaluates the config before loading mode-specific environment files.

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

- `vite` ^7.0.0 or ^8.0.0
- `@vitejs/plugin-vue` ^5.2.0 or ^6.0.0

## License

MIT
