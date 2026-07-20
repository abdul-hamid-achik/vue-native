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

import { parseDirectory, parseSFC, type NativeBlock } from '@thelacanians/vue-native-sfc-parser'
import { cleanGeneratedFiles, generateCode, hasGeneratedArtifacts, writeGeneratedFiles, type CodegenResult } from '@thelacanians/vue-native-codegen'
import fg from 'fast-glob'
import { realpathSync } from 'node:fs'
import type { ConfigEnv, LibraryFormats, ResolvedConfig, UserConfig, ViteDevServer } from 'vite'

export type NativePlatform = 'ios' | 'android' | 'macos'

export interface VueNativePluginOptions {
  /**
   * Target platform.
   * - `'ios'` — JavaScriptCore (built into iOS)
   * - `'android'` — V8 via J2V8
   * - `'macos'` — JavaScriptCore (same as iOS)
   * Used when VUE_NATIVE_PLATFORM is not present.
   * @default 'ios' when neither this option nor VUE_NATIVE_PLATFORM is set
   */
  platform?: NativePlatform

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

const NATIVE_PLATFORMS = new Set<NativePlatform>(['ios', 'android', 'macos'])
const REQUIRED_NATIVE_VUE_RUNTIMES = [
  '@vue/reactivity',
  '@vue/runtime-core',
] as const

function isNativePlatform(value: string): value is NativePlatform {
  return NATIVE_PLATFORMS.has(value as NativePlatform)
}

function resolvePlatform(explicitPlatform: NativePlatform | undefined): NativePlatform {
  const environmentPlatform = process.env.VUE_NATIVE_PLATFORM
  if (environmentPlatform !== undefined) {
    if (!isNativePlatform(environmentPlatform)) {
      throw new Error(
        `[vue-native] Invalid VUE_NATIVE_PLATFORM "${environmentPlatform}". Expected "ios", "android", or "macos".`,
      )
    }
    return environmentPlatform
  }

  if (explicitPlatform !== undefined) {
    if (!isNativePlatform(explicitPlatform)) {
      throw new Error(
        `[vue-native] Invalid platform option "${explicitPlatform}". Expected "ios", "android", or "macos".`,
      )
    }
    return explicitPlatform
  }

  // Preserve the original direct-Vite behavior. Platform-targeted CLI
  // commands provide VUE_NATIVE_PLATFORM instead of reaching this fallback.
  return 'ios'
}

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

type LocatedSfcBlock = {
  type: string
  content: string
  attrs: Record<string, string | true>
  loc: {
    start: { offset: number }
    end: { offset: number }
  }
}

function hasVaporAttribute(block: LocatedSfcBlock | null | undefined): boolean {
  return block !== null
    && block !== undefined
    && Object.prototype.hasOwnProperty.call(block.attrs, 'vapor')
}

function hasStaticVaporAttribute(rawAttributes: string): boolean {
  let index = 0

  while (index < rawAttributes.length) {
    while (/\s/.test(rawAttributes[index] ?? '')) index++
    if (index >= rawAttributes.length || rawAttributes[index] === '/') break

    const nameStart = index
    while (
      index < rawAttributes.length
      && !/[\s=/>]/.test(rawAttributes[index] ?? '')
    ) {
      index++
    }

    if (nameStart === index) {
      index++
      continue
    }

    const name = rawAttributes.slice(nameStart, index)
    while (/\s/.test(rawAttributes[index] ?? '')) index++

    if (rawAttributes[index] === '=') {
      index++
      while (/\s/.test(rawAttributes[index] ?? '')) index++

      const quote = rawAttributes[index]
      if (quote === '"' || quote === '\'') {
        index++
        while (index < rawAttributes.length && rawAttributes[index] !== quote) index++
        if (rawAttributes[index] === quote) index++
      } else {
        while (
          index < rawAttributes.length
          && !/[\s>]/.test(rawAttributes[index] ?? '')
        ) {
          index++
        }
      }
    }

    if (name === 'vapor') return true
  }

  return false
}

/**
 * Vue 3.5 drops whitespace-only script blocks from its descriptor. Vue 3.6
 * still treats a `vapor` marker on such a block as an SFC-wide opt-in, so
 * inspect only those ignored top-level blocks after masking parsed contents.
 */
function hasIgnoredEmptyScriptVaporMarker(
  source: string,
  blocks: LocatedSfcBlock[],
): boolean {
  const maskedSource = source.split('')
  const mask = (start: number, end: number) => {
    maskedSource.fill(' ', Math.max(0, start), Math.min(source.length, end))
  }

  for (const block of blocks) {
    mask(block.loc.start.offset, block.loc.end.offset)
  }

  for (const comment of source.matchAll(/<!--[\s\S]*?(?:-->|$)/g)) {
    const start = comment.index ?? 0
    mask(start, start + comment[0].length)
  }

  const emptyScriptPattern
    = /<script\b((?:[^"'<>]|"[^"]*"|'[^']*')*)(?:\/\s*>|>\s*<\/script\s*>)/g

  for (const match of maskedSource.join('').matchAll(emptyScriptPattern)) {
    if (hasStaticVaporAttribute(match[1] ?? '')) return true
  }

  return false
}

function hasVaporOptIn(source: string, filename: string): boolean {
  if (!source.includes('vapor')) return false

  const { descriptor } = parseSFC(source, { sourceFile: filename })
  const vaporBlocks = [
    descriptor.template,
    descriptor.script,
    descriptor.scriptSetup,
  ]

  if (vaporBlocks.some(hasVaporAttribute)) return true

  const parsedBlocks = [
    ...vaporBlocks,
    ...descriptor.styles,
    ...descriptor.customBlocks,
  ]
  const locatedBlocks: LocatedSfcBlock[] = []

  for (const block of parsedBlocks) {
    if (block === null) continue
    locatedBlocks.push(block)
  }

  return hasIgnoredEmptyScriptVaporMarker(source, locatedBlocks)
}

function resolveRawVueSfcId(id: string): string | null {
  if (id.includes('?')) return null
  return id.toLowerCase().endsWith('.vue') ? id : null
}

function assertVaporIsNotForced(config: ResolvedConfig, platform: NativePlatform): void {
  const vuePlugin = (config.plugins ?? []).find(plugin => plugin.name === 'vite:vue')
  const vuePluginApi = (vuePlugin as {
    api?: {
      options?: {
        script?: {
          vapor?: boolean
        }
      }
    }
  } | undefined)?.api

  if (vuePluginApi?.options?.script?.vapor !== true) return

  throw new Error(
    `[vue-native] VN_VAPOR_UNSUPPORTED: Vue 3.6 Vapor Mode is not supported for the "${platform}" native target. `
    + 'Disable the global vue({ script: { vapor: true } }) option. '
    + 'Vue Native currently requires Vue\'s VDOM custom-renderer compilation path.',
  )
}

function packageResolutionRoots(moduleIds: string[], packageName: string): string[] {
  const marker = `/node_modules/${packageName}/`
  const roots = new Set<string>()

  for (const moduleId of moduleIds) {
    const markerIndex = moduleId.lastIndexOf(marker)
    if (markerIndex === -1) continue
    const packageRoot = moduleId.slice(0, markerIndex + marker.length - 1)
    try {
      roots.add(realpathSync(packageRoot).replace(/\\/g, '/'))
    } catch {
      // Synthetic module IDs used by tests and non-filesystem resolvers have
      // no realpath. Their normalized resolver identity is still meaningful.
      roots.add(packageRoot)
    }
  }

  return [...roots].sort()
}

export default function vueNativePlugin(options: VueNativePluginOptions = {}) {
  const {
    platform: explicitPlatform,
    globalName = 'VueNativeApp',
    hotReload = true,
    hotReloadPort = 8174,
    nativeCodegen = true,
    nativeOutputDirs,
    exclude = ['node_modules', 'dist', '.git', '.turbo'],
  } = options
  const platform = resolvePlatform(explicitPlatform)

  const state: CodegenState = {
    lastResult: null,
    lastError: null,
    blocks: [],
  }

  let projectRoot = ''
  let codegenQueue: Promise<CodegenResult | null> = Promise.resolve(null)

  /**
   * Run code generation
   */
  async function performCodegen(root: string): Promise<CodegenResult | null> {
    if (!nativeCodegen) {
      return null
    }

    try {
      const codegenOptions = {
        root,
        iosOutputDir: nativeOutputDirs?.ios,
        androidOutputDir: nativeOutputDirs?.android,
        macosOutputDir: nativeOutputDirs?.macos,
        typescriptOutputDir: nativeOutputDirs?.typescript,
      }

      // Find all SFC files
      const sfcs = await fg('**/*.vue', {
        cwd: root,
        ignore: exclude,
        absolute: true,
      })

      // Parse SFCs and extract native blocks. A project can legitimately have
      // no SFCs/native blocks after a deletion; that must clear generated
      // modules instead of leaving stale registries behind.
      const parseResult = sfcs.length === 0
        ? { errors: [], allNativeBlocks: [] }
        : parseDirectory('.', { root, exclude })

      if (parseResult.errors.length > 0) {
        const error = new Error(
          `Native block parsing failed with ${parseResult.errors.length} error${parseResult.errors.length === 1 ? '' : 's'}`,
        )
        state.blocks = parseResult.allNativeBlocks
        state.lastResult = {
          files: [],
          errors: parseResult.errors,
          warnings: [],
          stats: {
            totalBlocks: state.blocks.length,
            swiftFiles: 0,
            kotlinFiles: 0,
            typescriptFiles: 0,
          },
        }
        state.lastError = error
        console.error('[vue-native] Parse errors:', parseResult.errors)
        return null
      }

      state.blocks = parseResult.allNativeBlocks

      // Do not create a default native project tree in a JavaScript-only app.
      // Once codegen has created output, though, an empty block list means the
      // final block was removed and those artifacts must be cleaned/replaced.
      if (state.blocks.length === 0 && !hasGeneratedArtifacts(codegenOptions, root)) {
        const emptyResult: CodegenResult = {
          files: [],
          errors: [],
          warnings: [],
          stats: {
            totalBlocks: 0,
            swiftFiles: 0,
            kotlinFiles: 0,
            typescriptFiles: 0,
          },
        }
        state.lastResult = emptyResult
        state.lastError = null
        logInfo('[vue-native] No <native> blocks or generated artifacts; skipping code generation')
        return emptyResult
      }

      // Generate code
      const codegenResult = generateCode(state.blocks, codegenOptions)

      if (codegenResult.errors.length > 0) {
        state.lastResult = codegenResult
        state.lastError = new Error('Code generation validation failed')
        console.error('[vue-native] Codegen errors:', codegenResult.errors)
        return null
      }

      // Prune only files carrying the generator marker, then write the full
      // current set. This handles both deleted blocks and deleted final blocks.
      cleanGeneratedFiles(codegenOptions, root)
      const writeResult = writeGeneratedFiles(codegenResult, root)

      if (writeResult.errors.length > 0) {
        const error = new Error(
          `Code generation failed to write ${writeResult.errors.length} file${writeResult.errors.length === 1 ? '' : 's'}`,
        )
        state.lastResult = codegenResult
        state.lastError = error
        console.error('[vue-native] Write errors:', writeResult.errors)
        return null
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

  /**
   * Serialize codegen runs so rapid add/change/unlink watcher events cannot
   * interleave cleanup and writes and leave output from an older scan behind.
   */
  function runCodegen(root: string): Promise<CodegenResult | null> {
    const nextRun = codegenQueue.then(
      () => performCodegen(root),
      () => performCodegen(root),
    )
    codegenQueue = nextRun
    return nextRun
  }

  return {
    name: 'vue-native',
    // This plugin must see raw SFC source before @vitejs/plugin-vue compiles
    // Vapor markers into DOM-specific output.
    enforce: 'pre' as const,

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
      assertVaporIsNotForced(config, platform)

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
      const regenerateForSfc = async (file: string) => {
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
      }

      // Deleting the final SFC/native block is just as important as editing
      // one: stale generated classes and registries must be removed. Watching
      // additions also makes newly created SFCs participate immediately.
      server.watcher.on('add', regenerateForSfc)
      server.watcher.on('change', regenerateForSfc)
      server.watcher.on('unlink', regenerateForSfc)
    },

    /**
     * Called before build starts.
     * Run codegen to ensure generated files are up to date.
     */
    async buildStart() {
      if (nativeCodegen && projectRoot) {
        await runCodegen(projectRoot)
        if (state.lastError) {
          throw state.lastError
        }
      }
    },

    /**
     * Verify the resolved module graph, which is more reliable than scanning a
     * minified bundle for implementation strings. Vue's runtime-core itself
     * contains a hydration-only `document.createElement` fallback, so that
     * string alone does not prove that runtime-dom was bundled.
     */
    generateBundle(this: { getModuleIds(): IterableIterator<string> }) {
      const moduleIds = [...this.getModuleIds()]
        .map(moduleId => moduleId.replace(/\\/g, '/'))
      const observedVueModuleIds = moduleIds
        .filter(moduleId =>
          moduleId.includes('/@vue/')
          || moduleId.includes('/vue/'),
        )
      const forbiddenRendererModules = moduleIds
        .filter(moduleId =>
          moduleId.includes('/node_modules/@vue/runtime-dom/')
          || moduleId.includes('/node_modules/@vue/runtime-vapor/')
          || moduleId.includes('/node_modules/vue/dist/'),
        )
      const runtimeResolutionErrors = REQUIRED_NATIVE_VUE_RUNTIMES.flatMap(
        (packageName) => {
          const roots = packageResolutionRoots(moduleIds, packageName)
          if (roots.length === 1) return []
          return [
            `${packageName} resolved through ${roots.length} physical copies: ${
              roots.length === 0 ? '(missing)' : roots.join(', ')
            }${
              roots.length === 0 && observedVueModuleIds.length > 0
                ? `; observed Vue modules: ${observedVueModuleIds.join(', ')}`
                : ''
            }`,
          ]
        },
      )

      if (
        forbiddenRendererModules.length > 0
        || runtimeResolutionErrors.length > 0
      ) {
        throw new Error(
          '[vue-native] VN_RENDERER_ISOLATION: The native bundle must resolve exactly one copy of each core Vue runtime and no unsupported Vue renderer:\n'
          + [
            ...runtimeResolutionErrors,
            ...forbiddenRendererModules.map(
              moduleId => `unsupported Vue renderer: ${moduleId}`,
            ),
          ].map(message => `- ${message}`).join('\n'),
        )
      }
    },

    /**
     * Strip <native> custom blocks — they contain Swift/Kotlin code
     * that should not be processed by Rollup/esbuild.
     * The vue plugin loads the raw content; we transform it to a no-op.
     */
    transform(code: string, id: string) {
      if (id.includes('type=native')) {
        return { code: 'export default () => {}', map: null }
      }

      const filename = resolveRawVueSfcId(id)
      if (filename && hasVaporOptIn(code, filename)) {
        throw new Error(
          `[vue-native] VN_VAPOR_UNSUPPORTED: Vue 3.6 Vapor Mode is not supported for the "${platform}" native target in ${filename}. `
          + 'Remove the "vapor" attribute from the top-level <script>, <script setup>, or <template> block. '
          + 'Vue Native currently requires Vue\'s VDOM custom-renderer compilation path.',
        )
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
