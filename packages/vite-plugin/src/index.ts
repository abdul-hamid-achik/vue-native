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
 * - Extract <native> blocks and generate Swift/Kotlin/TypeScript code
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

import { parseDirectory, type NativeBlock } from '@thelacanians/vue-native-sfc-parser'
import { generateCode, writeGeneratedFiles, type CodegenResult } from '@thelacanians/vue-native-codegen'
import fg from 'fast-glob'
import type { ConfigEnv, LibraryFormats, ResolvedConfig, UserConfig, ViteDevServer } from 'vite'

export interface VueNativePluginOptions {
  /**
   * Target platform.
   * - `'ios'` — JavaScriptCore (built into iOS)
   * - `'android'` — V8 via J2V8
   * - `'macos'` — JavaScriptCore (same as iOS)
   * @default 'ios'
   */
  platform?: 'ios' | 'android' | 'macos'

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

  /**
   * Enable native code generation from <native> blocks.
   * When true, scans SFC files for <native> blocks and generates
   * Swift/Kotlin/TypeScript code.
   * @default true
   */
  nativeCodegen?: boolean

  /**
   * Output directory for generated native code.
   * Paths are relative to project root.
   */
  nativeOutputDirs?: {
    /**
     * iOS Swift output directory
     * @default 'native/ios/VueNativeCore/Sources/VueNativeCore/GeneratedModules'
     */
    ios?: string

    /**
     * Android Kotlin output directory
     * @default 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/GeneratedModules'
     */
    android?: string

    /**
     * macOS Swift output directory
     * @default 'native/macos/VueNativeMacOS/Sources/VueNativeMacOS/GeneratedModules'
     */
    macos?: string

    /**
     * TypeScript composables output directory
     * @default 'packages/runtime/src/generated'
     */
    typescript?: string
  }

  /**
   * Patterns to exclude from SFC scanning.
   * @default ['node_modules', 'dist', '.git', '.turbo']
   */
  exclude?: string[]
}

interface CodegenState {
  lastResult: CodegenResult | null
  lastError: Error | null
  blocks: NativeBlock[]
}

type AliasEntry = {
  find: string | RegExp
  replacement: string
}

type AliasConfig = Record<string, string> | AliasEntry[]

function mergeAliases(existingAlias: AliasConfig | undefined): AliasConfig {
  const replacement = '@thelacanians/vue-native-runtime'

  if (Array.isArray(existingAlias)) {
    return [
      { find: 'vue', replacement },
      ...existingAlias.filter(alias => alias.find !== 'vue'),
    ]
  }

  return {
    ...(existingAlias ?? {}),
    vue: replacement,
  }
}

function logInfo(message: string): void {
  process.stdout.write(`${message}\n`)
}

function resolveLibEntry(config: UserConfig): string {
  const lib = config.build?.lib
  if (lib && typeof lib === 'object' && typeof lib.entry === 'string') {
    return lib.entry
  }

  return 'app/main.ts'
}

export default function vueNativePlugin(options: VueNativePluginOptions = {}) {
  const {
    platform = 'ios',
    globalName = 'VueNativeApp',
    hotReload = true,
    hotReloadPort = 8174,
    nativeCodegen = true,
    nativeOutputDirs,
    exclude = ['node_modules', 'dist', '.git', '.turbo'],
  } = options

  const state: CodegenState = {
    lastResult: null,
    lastError: null,
    blocks: [],
  }

  let projectRoot = ''

  /**
   * Run code generation
   */
  async function runCodegen(root: string): Promise<CodegenResult | null> {
    if (!nativeCodegen) {
      return null
    }

    try {
      // Find all SFC files
      const sfcs = await fg('**/*.vue', {
        cwd: root,
        ignore: exclude,
        absolute: true,
      })

      if (sfcs.length === 0) {
        return null
      }

      // Parse SFCs and extract native blocks
      const parseResult = parseDirectory('.', {
        root,
        exclude,
      })

      if (parseResult.errors.length > 0) {
        console.warn('[vue-native] Parse errors:', parseResult.errors)
      }

      state.blocks = parseResult.allNativeBlocks

      if (state.blocks.length === 0) {
        return null
      }

      // Generate code
      const codegenResult = generateCode(state.blocks, {
        root,
        iosOutputDir: nativeOutputDirs?.ios,
        androidOutputDir: nativeOutputDirs?.android,
        macosOutputDir: nativeOutputDirs?.macos,
        typescriptOutputDir: nativeOutputDirs?.typescript,
      })

      // Write files to disk
      const writeResult = writeGeneratedFiles(codegenResult, root)

      if (writeResult.errors.length > 0) {
        console.error('[vue-native] Write errors:', writeResult.errors)
      }

      state.lastResult = codegenResult
      state.lastError = null

      logInfo(`[vue-native] Generated ${codegenResult.stats.swiftFiles} Swift, ${codegenResult.stats.kotlinFiles} Kotlin, ${codegenResult.stats.typescriptFiles} TypeScript files`)

      return codegenResult
    } catch (error) {
      state.lastError = error as Error
      console.error('[vue-native] Codegen error:', error)
      return null
    }
  }

  return {
    name: 'vue-native',

    /**
     * Modify Vite's resolved config to set up aliases, defines, and build
     * settings appropriate for a native iOS or Android target.
     */
    config(config: UserConfig, env: ConfigEnv): UserConfig {
      const isDev = env.mode !== 'production'

      return {
        resolve: {
          // Redirect all 'vue' imports to the native runtime while preserving
          // any aliases already defined by the user.
          alias: mergeAliases(config.resolve?.alias as AliasConfig | undefined),
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
            entry: resolveLibEntry(config),
            formats: ['iife'] satisfies LibraryFormats[],
            name: globalName,
            fileName: () => 'vue-native-bundle.js',
          },

          rollupOptions: {
            output: {
              // Disable code splitting — Vite's IIFE lib build already emits a
              // single bundle, and explicitly setting inlineDynamicImports now
              // triggers Rolldown warnings on Vite 8.
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

    /**
     * Called after Vite config is resolved.
     * Store project root and run initial codegen.
     */
    async configResolved(config: ResolvedConfig) {
      projectRoot = config.root || process.cwd()

      if (nativeCodegen) {
        logInfo('[vue-native] Running initial code generation...')
        await runCodegen(projectRoot)
      }
    },

    /**
     * Called when Vite dev server starts.
     * Run initial codegen.
     */
    async configureServer(server: ViteDevServer) {
      if (!nativeCodegen) return

      // Watch for SFC changes
      server.watcher.on('change', async (file: string) => {
        if (file.endsWith('.vue')) {
          logInfo('[vue-native] SFC changed, regenerating code...')
          await runCodegen(projectRoot)

          // Notify HMR about codegen update
          if (server.ws) {
            server.ws.send({
              type: 'custom',
              event: 'vue-native:codegen',
              data: {
                success: state.lastError === null,
                error: state.lastError?.message,
                stats: state.lastResult?.stats,
              },
            })
          }
        }
      })
    },

    /**
     * Called before build starts.
     * Run codegen to ensure generated files are up to date.
     */
    async buildStart() {
      if (nativeCodegen && projectRoot) {
        await runCodegen(projectRoot)
      }
    },

    /**
     * Strip <native> custom blocks — they contain Swift/Kotlin code
     * that should not be processed by Rollup/esbuild.
     */
    /**
     * Strip <native> custom blocks — they contain Swift/Kotlin code
     * that should not be processed by Rollup/esbuild.
     * The vue plugin loads the raw content; we transform it to a no-op.
     */
    transform(_code: string, id: string) {
      if (id.includes('type=native')) {
        return { code: 'export default () => {}', map: null }
      }
    },

    /**
     * Expose codegen state for other plugins or tools.
     */
    api: {
      /**
       * Get the last codegen result.
       */
      getLastResult: () => state.lastResult,

      /**
       * Get the last error.
       */
      getLastError: () => state.lastError,

      /**
       * Get extracted native blocks.
       */
      getNativeBlocks: () => state.blocks,

      /**
       * Trigger manual codegen run.
       */
      runCodegen: () => runCodegen(projectRoot),
    },
  }
}
