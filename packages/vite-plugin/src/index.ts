/**
 * @thelacanians/vue-native-vite-plugin — Vite plugin for building Vue Native applications.
 *
 * This plugin is used ALONGSIDE @vitejs/plugin-vue (not as a replacement).
 * It configures Vite to:
 * - Alias 'vue' imports to '@thelacanians/vue-native-runtime' so that Vue SFCs use the
 *   native renderer instead of the DOM renderer
 * - Define __DEV__ and __PLATFORM__ compile-time constants
 * - Configure the build for IIFE output suitable for embedding in a native
 *   app's JavaScript runtime (JavaScriptCore on iOS, V8/J2V8 on Android)
 *
 * @example
 * ```ts
 * // vite.config.ts
 * import vue from '@vitejs/plugin-vue'
 * import vueNative from '@thelacanians/vue-native-vite-plugin'
 *
 * export default defineConfig({
 *   plugins: [vue(), vueNative()],
 * })
 * ```
 */

export interface VueNativePluginOptions {
  /**
   * Target platform.
   * - `'ios'` — JavaScriptCore (built into iOS)
   * - `'android'` — V8 via J2V8
   * @default 'ios'
   */
  platform?: 'ios' | 'android'

  /**
   * The global variable name for the IIFE bundle.
   * @default 'VueNativeApp'
   */
  globalName?: string

  /**
   * Enable hot reload WebSocket server integration.
   * When true, configures the build for watch mode output.
   * @default true
   */
  hotReload?: boolean

  /**
   * Port for the hot reload WebSocket server (started by `vue-native dev`).
   * @default 8174
   */
  hotReloadPort?: number
}

export default function vueNativePlugin(options: VueNativePluginOptions = {}) {
  const { platform = 'ios', globalName = 'VueNativeApp', hotReload = true, hotReloadPort = 8174 } = options

  return {
    name: 'vue-native',

    /**
     * Modify Vite's resolved config to set up aliases, defines, and build
     * settings appropriate for a native iOS or Android target.
     */
    config(config: any, env: { mode: string }) {
      const isDev = env.mode !== 'production'

      return {
        resolve: {
          alias: {
            // Redirect all 'vue' imports to the native runtime.
            // This means when @vitejs/plugin-vue compiles SFCs and they
            // import from 'vue', they actually get '@thelacanians/vue-native-runtime'
            // which uses the native renderer instead of the DOM renderer.
            vue: '@thelacanians/vue-native-runtime',
          },
        },

        define: {
          // Compile-time flag for development-only code paths
          '__DEV__': JSON.stringify(isDev),
          // Platform identifier available at compile time
          '__PLATFORM__': JSON.stringify(platform),
          // Hot reload configuration available at compile time
          '__HOT_RELOAD__': JSON.stringify(hotReload && isDev),
          '__HOT_RELOAD_PORT__': JSON.stringify(hotReloadPort),
          // Replace process.env.NODE_ENV references from @vue/shared and
          // @vue/runtime-core. JavaScriptCore has no `process` global, so
          // leaving these unresolved would crash the bundle on load.
          'process.env.NODE_ENV': JSON.stringify(isDev ? 'development' : 'production'),
        },

        build: {
          // Target ES2020 for modern JavaScript engine compatibility
          // (JavaScriptCore on iOS and V8/J2V8 on Android both support ES2020+)
          target: 'es2020',

          // IIFE output for embedding in native app
          lib: {
            entry: config.build?.lib?.entry || 'app/main.ts',
            formats: ['iife'] as any,
            name: globalName,
            fileName: () => 'vue-native-bundle.js',
          },

          rollupOptions: {
            output: {
              // Ensure everything is inlined into a single file
              inlineDynamicImports: true,

              // Disable code splitting — we need a single bundle file
              manualChunks: undefined,
            },
          },

          // Don't clear the output directory (native project may have other files)
          emptyOutDir: false,

          // Disable watching when hot reload is turned off
          watch: hotReload && isDev ? undefined : null,

          // Generate source maps for debugging in native dev tools
          sourcemap: isDev,

          // Minify in production
          minify: isDev ? false : 'esbuild',
        },
      }
    },
  }
}
