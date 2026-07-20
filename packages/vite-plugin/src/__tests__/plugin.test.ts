/**
 * Vite plugin tests — verifies plugin creation, config generation for
 * production and development modes, custom options handling, and edge cases.
 *
 * These tests call plugin hooks directly (the same way Vite itself does)
 * to validate the resolved configuration without needing a real Vite build.
 */
import { describe, it, expect } from 'vitest'
import { ref as createProbeRef } from '@vue/reactivity'
import { nextTick as scheduleProbeTick } from '@vue/runtime-core'
import { existsSync } from 'node:fs'
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { build } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueNativePlugin from '../index'
import type { ConfigEnv, UserConfig } from 'vite'
import type { VueNativePluginOptions } from '../index'

interface TestPluginConfig {
  resolve: {
    // Tests exercise both Vite-supported alias representations. The
    // intersection keeps property and array assertions type-safe here.
    alias: Record<string, string> & Array<{ find: string | RegExp, replacement: string }>
  }
  define: Record<string, string>
  build: {
    target: string
    lib: {
      entry: string
      formats: string[]
      name: string
      fileName: () => string
    }
    rollupOptions: {
      output: {
        inlineDynamicImports?: boolean
        manualChunks?: unknown
      }
    }
    minify: false | 'esbuild'
    sourcemap: boolean
    emptyOutDir: boolean
  }
}

// Helper: invoke the plugin's config hook and return the result.
function getPluginConfig(
  pluginOptions?: VueNativePluginOptions,
  env: { mode: string, command?: ConfigEnv['command'] } = { mode: 'production' },
  userConfig: UserConfig = {},
): TestPluginConfig {
  const plugin = vueNativePlugin(pluginOptions)
  return plugin.config(userConfig, {
    command: env.command ?? 'build',
    mode: env.mode,
  }) as TestPluginConfig
}

// ---------------------------------------------------------------------------
// Plugin creation
// ---------------------------------------------------------------------------
describe('Plugin creation', () => {
  it('returns a valid Vite plugin object', () => {
    const plugin = vueNativePlugin()
    expect(plugin).toBeDefined()
    expect(typeof plugin).toBe('object')
  })

  it('has the correct plugin name', () => {
    const plugin = vueNativePlugin()
    expect(plugin.name).toBe('vue-native')
  })

  it('runs before the Vue SFC compiler', () => {
    const plugin = vueNativePlugin()
    expect(plugin.enforce).toBe('pre')
  })

  it('has a config hook', () => {
    const plugin = vueNativePlugin()
    expect(plugin.config).toBeDefined()
    expect(typeof plugin.config).toBe('function')
  })
})

describe('Vue 3.6 Vapor diagnostics', () => {
  it.each([
    ['script setup marker', '<script setup vapor>const count = 1</script><template><VText /></template>'],
    ['script shorthand marker', '<script vapor>const count = 1</script><template><VText /></template>'],
    ['template marker', '<template vapor><VText /></template>'],
    ['empty script shorthand', '<script vapor></script><template><VText /></template>'],
    ['empty script setup marker', '<script setup vapor />\n<template><VText /></template>'],
    ['valued marker', '<template vapor="false"><VText /></template>'],
  ])('rejects the Vue-supported %s', (_label, source) => {
    const plugin = vueNativePlugin({ platform: 'android' })

    expect(() => plugin.transform(source, '/project/app/App.vue')).toThrow(
      /VN_VAPOR_UNSUPPORTED.*"android".*App\.vue.*<script>.*<script setup>.*<template>/,
    )
  })

  it.each([
    ['comment', '<!-- <script setup vapor>const count = 1</script> --><template><VText /></template>'],
    ['identifier', '<script setup>const vapor = true</script><template><VText>{{ vapor }}</VText></template>'],
    ['attribute value', '<script setup data-note="enable vapor later">const count = 1</script><template><VText /></template>'],
    ['similarly named attribute', '<script setup vaporous data-vapor>const count = 1</script><template><VText /></template>'],
    ['dynamic attribute', '<script setup :vapor="enabled">const enabled = true</script><template><VText /></template>'],
    ['case-mismatched attribute', '<script setup VAPOR>const count = 1</script><template><VText /></template>'],
    ['nested script element', '<template><VView><script vapor></script></VView></template>'],
    ['style attribute', '<style vapor>.label { color: red; }</style><template><VText class="label" /></template>'],
    ['custom-block attribute', '<native platform="ios" vapor>final class VaporModule {}</native><template><VText /></template>'],
  ])('does not mistake a %s for an SFC Vapor opt-in', (_label, source) => {
    const plugin = vueNativePlugin()
    expect(plugin.transform(source, '/project/app/App.vue')).toBeUndefined()
  })

  it('ignores compiled Vue subrequests', () => {
    const plugin = vueNativePlugin()
    const compiledCode = 'const message = "<script setup vapor>"'

    expect(
      plugin.transform(compiledCode, '/project/app/App.vue?vue&type=script&setup=true&lang.ts'),
    ).toBeUndefined()
  })

  it('continues to strip native custom-block subrequests', () => {
    const plugin = vueNativePlugin()

    expect(
      plugin.transform('native source', '/project/app/App.vue?vue&type=native&index=0'),
    ).toEqual({ code: 'export default () => {}', map: null })
  })
})

describe('Renderer isolation', () => {
  function runGenerateBundle(moduleIds: string[]) {
    const plugin = vueNativePlugin()
    if (typeof plugin.generateBundle !== 'function') {
      throw new TypeError('Expected a generateBundle hook')
    }
    return plugin.generateBundle.call({
      getModuleIds: () => moduleIds.values(),
    } as any)
  }

  it('accepts the custom renderer and runtime-core module graph', () => {
    expect(createProbeRef('native').value).toBe('native')
    expect(typeof scheduleProbeTick).toBe('function')
    expect(() => runGenerateBundle([
      '/project/packages/runtime/dist/index.js',
      '/project/node_modules/@vue/reactivity/dist/reactivity.esm-bundler.js',
      '/project/node_modules/@vue/runtime-core/dist/runtime-core.esm-bundler.js',
    ])).not.toThrow()
  })

  it.each([
    '/project/node_modules/@vue/runtime-dom/dist/runtime-dom.esm-bundler.js',
    '/project/node_modules/@vue/runtime-vapor/dist/runtime-vapor.esm-bundler.js',
    'C:\\project\\node_modules\\vue\\dist\\vue.runtime.esm-bundler.js',
  ])('rejects unsupported renderer module %s', (moduleId) => {
    expect(() => runGenerateBundle([
      '/project/node_modules/@vue/reactivity/dist/reactivity.esm-bundler.js',
      '/project/node_modules/@vue/runtime-core/dist/runtime-core.esm-bundler.js',
      moduleId,
    ])).toThrow(
      /VN_RENDERER_ISOLATION.*unsupported Vue renderer/s,
    )
  })

  it('rejects two same-version physical runtime copies', () => {
    expect(() => runGenerateBundle([
      '/project/node_modules/@vue/reactivity/dist/reactivity.esm-bundler.js',
      '/project/node_modules/.bun/@vue+runtime-core@3.5.40/node_modules/@vue/runtime-core/dist/runtime-core.esm-bundler.js',
      '/project/node_modules/legacy/node_modules/@vue/runtime-core/dist/runtime-core.esm-bundler.js',
    ])).toThrow(
      /VN_RENDERER_ISOLATION.*runtime-core resolved through 2 physical copies/s,
    )
  })
})

describe('Native codegen cleanup', () => {
  it('does not create a native tree when no native blocks or generated artifacts exist', async () => {
    const root = await mkdtemp(join(process.cwd(), 'tmp-vue-native-codegen-'))

    try {
      await mkdir(join(root, 'app'), { recursive: true })
      await writeFile(join(root, 'app', 'App.vue'), '<template><VView /></template>')

      const plugin = vueNativePlugin()
      await plugin.configResolved?.({ root } as any)

      expect(existsSync(join(root, 'native'))).toBe(false)
    } finally {
      await rm(root, { recursive: true, force: true })
    }
  })

  it('removes stale generated modules and writes empty registries after the final block is deleted', async () => {
    const root = await mkdtemp(join(process.cwd(), 'tmp-vue-native-codegen-'))
    const outputDirs = {
      ios: 'generated/ios',
      android: 'generated/android',
      macos: 'generated/macos',
      typescript: 'generated/typescript',
    }

    try {
      await mkdir(join(root, 'app'), { recursive: true })
      await writeFile(join(root, 'app', 'App.vue'), '<template><VView /></template>')
      const staleModule = join(root, outputDirs.ios, 'StaleModule.swift')
      await mkdir(join(root, outputDirs.ios), { recursive: true })
      await writeFile(staleModule, '// Auto-Generated Code\nfinal class StaleModule {}\n')

      const plugin = vueNativePlugin({ nativeOutputDirs: outputDirs })
      await plugin.configResolved?.({ root } as any)

      await expect(readFile(staleModule, 'utf8')).rejects.toThrow()
      const registry = await readFile(join(root, outputDirs.ios, 'GeneratedModuleRegistry.swift'), 'utf8')
      expect(registry).toContain('registerGeneratedModules')
    } finally {
      await rm(root, { recursive: true, force: true })
    }
  })

  it('preserves the last valid generated output when SFC parsing fails', async () => {
    const root = await mkdtemp(join(process.cwd(), 'tmp-vue-native-codegen-'))
    const outputDirs = {
      ios: 'generated/ios',
      android: 'generated/android',
      macos: 'generated/macos',
      typescript: 'generated/typescript',
    }

    try {
      await mkdir(join(root, 'app'), { recursive: true })
      await writeFile(
        join(root, 'app', 'App.vue'),
        '<template><VView /></template><native>class BrokenModule {}</native>',
      )
      const staleModule = join(root, outputDirs.ios, 'LastValidModule.swift')
      await mkdir(join(root, outputDirs.ios), { recursive: true })
      await writeFile(staleModule, '// Auto-Generated Code\nfinal class LastValidModule {}\n')

      const plugin = vueNativePlugin({ nativeOutputDirs: outputDirs })
      await plugin.configResolved?.({ root } as any)

      expect(await readFile(staleModule, 'utf8')).toContain('LastValidModule')
      expect(plugin.api.getLastError()?.message).toContain('parsing failed')
      await expect((plugin.buildStart as () => Promise<void>)()).rejects.toThrow('parsing failed')
    } finally {
      await rm(root, { recursive: true, force: true })
    }
  })

  it('watches added, changed, and deleted SFCs for codegen updates', async () => {
    const registeredEvents: string[] = []
    const watcher = {
      on(event: string) {
        registeredEvents.push(event)
        return watcher
      },
    }
    const plugin = vueNativePlugin()

    await plugin.configureServer?.({ watcher } as any)

    expect(registeredEvents).toEqual(['add', 'change', 'unlink'])
  })
})

// ---------------------------------------------------------------------------
// Production mode config
// ---------------------------------------------------------------------------
describe('Config — production mode', () => {
  const config = getPluginConfig({}, { mode: 'production' })

  it('sets build target to es2020', () => {
    expect(config.build.target).toBe('es2020')
  })

  it('uses IIFE format', () => {
    expect(config.build.lib.formats).toEqual(['iife'])
  })

  it('leaves inlineDynamicImports unset to avoid Rolldown warnings', () => {
    expect(config.build.rollupOptions.output.inlineDynamicImports).toBeUndefined()
  })

  it('sets manualChunks to undefined (no code splitting)', () => {
    expect(config.build.rollupOptions.output.manualChunks).toBeUndefined()
  })

  it('enables minification with esbuild', () => {
    expect(config.build.minify).toBe('esbuild')
  })

  it('disables sourcemaps', () => {
    expect(config.build.sourcemap).toBe(false)
  })

  it('defines __DEV__ as false', () => {
    expect(config.define['__DEV__']).toBe(JSON.stringify(false))
  })

  it('defines process.env.NODE_ENV as "production"', () => {
    expect(config.define['process.env.NODE_ENV']).toBe(JSON.stringify('production'))
  })

  it('does not empty the output directory', () => {
    expect(config.build.emptyOutDir).toBe(false)
  })
})

// ---------------------------------------------------------------------------
// Development mode config
// ---------------------------------------------------------------------------
describe('Config — development mode', () => {
  const config = getPluginConfig({}, { mode: 'development' })

  it('enables sourcemaps', () => {
    expect(config.build.sourcemap).toBe(true)
  })

  it('disables minification', () => {
    expect(config.build.minify).toBe(false)
  })

  it('defines __DEV__ as true', () => {
    expect(config.define['__DEV__']).toBe(JSON.stringify(true))
  })

  it('defines process.env.NODE_ENV as "development"', () => {
    expect(config.define['process.env.NODE_ENV']).toBe(JSON.stringify('development'))
  })

  it('still uses IIFE format', () => {
    expect(config.build.lib.formats).toEqual(['iife'])
  })

  it('still uses es2020 target', () => {
    expect(config.build.target).toBe('es2020')
  })

  it('still leaves inlineDynamicImports unset in development', () => {
    expect(config.build.rollupOptions.output.inlineDynamicImports).toBeUndefined()
  })

  it('still disables code splitting', () => {
    expect(config.build.rollupOptions.output.manualChunks).toBeUndefined()
  })
})

// ---------------------------------------------------------------------------
// Vue alias
// ---------------------------------------------------------------------------
describe('Config — Vue alias', () => {
  it('aliases vue to @thelacanians/vue-native-runtime', () => {
    const config = getPluginConfig()
    expect(config.resolve.alias.vue).toBe('@thelacanians/vue-native-runtime')
  })

  it('sets the alias regardless of mode', () => {
    const devConfig = getPluginConfig({}, { mode: 'development' })
    const prodConfig = getPluginConfig({}, { mode: 'production' })
    expect(devConfig.resolve.alias.vue).toBe('@thelacanians/vue-native-runtime')
    expect(prodConfig.resolve.alias.vue).toBe('@thelacanians/vue-native-runtime')
  })

  it('preserves object aliases already defined by the user', () => {
    const config = getPluginConfig({}, { mode: 'production' }, {
      resolve: {
        alias: {
          '@app': '/tmp/app',
        },
      },
    })

    expect(config.resolve.alias['@app']).toBe('/tmp/app')
    expect(config.resolve.alias.vue).toBe('@thelacanians/vue-native-runtime')
  })

  it('preserves array aliases already defined by the user', () => {
    const config = getPluginConfig({}, { mode: 'production' }, {
      resolve: {
        alias: [
          { find: '@app', replacement: '/tmp/app' },
        ],
      },
    })

    expect(Array.isArray(config.resolve.alias)).toBe(true)
    expect(config.resolve.alias).toEqual([
      { find: 'vue', replacement: '@thelacanians/vue-native-runtime' },
      { find: '@app', replacement: '/tmp/app' },
    ])
  })
})

// ---------------------------------------------------------------------------
// Platform option
// ---------------------------------------------------------------------------
describe('Config — platform option', () => {
  it('defaults direct Vite usage to "ios" when no target environment is present', () => {
    const previousPlatform = process.env.VUE_NATIVE_PLATFORM
    delete process.env.VUE_NATIVE_PLATFORM
    try {
      const config = getPluginConfig()
      expect(config.define['__PLATFORM__']).toBe(JSON.stringify('ios'))
    } finally {
      if (previousPlatform === undefined) delete process.env.VUE_NATIVE_PLATFORM
      else process.env.VUE_NATIVE_PLATFORM = previousPlatform
    }
  })

  it('sets __PLATFORM__ to "ios" when explicitly specified', () => {
    const config = getPluginConfig({ platform: 'ios' })
    expect(config.define['__PLATFORM__']).toBe(JSON.stringify('ios'))
  })

  it('sets __PLATFORM__ to "android" when specified', () => {
    const config = getPluginConfig({ platform: 'android' })
    expect(config.define['__PLATFORM__']).toBe(JSON.stringify('android'))
  })

  it('sets __PLATFORM__ to "macos" when specified', () => {
    const config = getPluginConfig({ platform: 'macos' })
    expect(config.define['__PLATFORM__']).toBe(JSON.stringify('macos'))
  })

  it.each(['ios', 'android', 'macos'] as const)(
    'uses VUE_NATIVE_PLATFORM=%s when the option is omitted',
    (platform) => {
      const previousPlatform = process.env.VUE_NATIVE_PLATFORM
      process.env.VUE_NATIVE_PLATFORM = platform
      try {
        const config = getPluginConfig()
        expect(config.define['__PLATFORM__']).toBe(JSON.stringify(platform))
      } finally {
        if (previousPlatform === undefined) delete process.env.VUE_NATIVE_PLATFORM
        else process.env.VUE_NATIVE_PLATFORM = previousPlatform
      }
    },
  )

  it('gives the environment target precedence over an explicit option', () => {
    const previousPlatform = process.env.VUE_NATIVE_PLATFORM
    process.env.VUE_NATIVE_PLATFORM = 'android'
    try {
      const config = getPluginConfig({ platform: 'macos' })
      expect(config.define['__PLATFORM__']).toBe(JSON.stringify('android'))
    } finally {
      if (previousPlatform === undefined) delete process.env.VUE_NATIVE_PLATFORM
      else process.env.VUE_NATIVE_PLATFORM = previousPlatform
    }
  })

  it('rejects an invalid environment target even when an explicit option is present', () => {
    const previousPlatform = process.env.VUE_NATIVE_PLATFORM
    process.env.VUE_NATIVE_PLATFORM = 'windows'
    try {
      expect(() => getPluginConfig({ platform: 'ios' })).toThrow(
        /Invalid VUE_NATIVE_PLATFORM.*ios.*android.*macos/,
      )
    } finally {
      if (previousPlatform === undefined) delete process.env.VUE_NATIVE_PLATFORM
      else process.env.VUE_NATIVE_PLATFORM = previousPlatform
    }
  })

  it.each(['', 'windows', 'ANDROID'])(
    'rejects invalid VUE_NATIVE_PLATFORM value %j',
    (platform) => {
      const previousPlatform = process.env.VUE_NATIVE_PLATFORM
      process.env.VUE_NATIVE_PLATFORM = platform
      try {
        expect(() => getPluginConfig()).toThrow(
          /Invalid VUE_NATIVE_PLATFORM.*ios.*android.*macos/,
        )
      } finally {
        if (previousPlatform === undefined) delete process.env.VUE_NATIVE_PLATFORM
        else process.env.VUE_NATIVE_PLATFORM = previousPlatform
      }
    },
  )

  it('rejects an invalid explicit option at runtime', () => {
    expect(() => getPluginConfig({ platform: 'windows' as 'ios' })).toThrow(
      /Invalid platform option.*ios.*android.*macos/,
    )
  })
})

// ---------------------------------------------------------------------------
// Global name option
// ---------------------------------------------------------------------------
describe('Config — globalName option', () => {
  it('defaults the IIFE global name to "VueNativeApp"', () => {
    const config = getPluginConfig()
    expect(config.build.lib.name).toBe('VueNativeApp')
  })

  it('uses a custom global name when specified', () => {
    const config = getPluginConfig({ globalName: 'MyApp' })
    expect(config.build.lib.name).toBe('MyApp')
  })
})

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
describe('Config — entry point', () => {
  it('defaults the entry to "app/main.ts"', () => {
    const config = getPluginConfig()
    expect(config.build.lib.entry).toBe('app/main.ts')
  })

  it('respects a user-provided entry via build.lib.entry', () => {
    const config = getPluginConfig({}, { mode: 'production' }, {
      build: { lib: { entry: 'src/app.ts' } },
    })
    expect(config.build.lib.entry).toBe('src/app.ts')
  })
})

// ---------------------------------------------------------------------------
// Output file name
// ---------------------------------------------------------------------------
describe('Config — output file name', () => {
  it('produces the bundle file name "vue-native-bundle.js"', () => {
    const config = getPluginConfig()
    // fileName is a function
    expect(typeof config.build.lib.fileName).toBe('function')
    expect(config.build.lib.fileName()).toBe('vue-native-bundle.js')
  })
})

// ---------------------------------------------------------------------------
// Edge cases
// ---------------------------------------------------------------------------
describe('Edge cases', () => {
  it('works when called with no options', () => {
    const plugin = vueNativePlugin()
    expect(plugin.name).toBe('vue-native')
    const config = getPluginConfig()
    expect(config).toBeDefined()
    expect(config.build).toBeDefined()
    expect(config.resolve).toBeDefined()
    expect(config.define).toBeDefined()
  })

  it('works when called with an empty options object', () => {
    const config = getPluginConfig({})
    expect(config.build.lib.name).toBe('VueNativeApp')
    expect(config.define['__PLATFORM__']).toBe(JSON.stringify('ios'))
  })

  it('works with ios platform', () => {
    const config = getPluginConfig({ platform: 'ios' })
    expect(config.define['__PLATFORM__']).toBe(JSON.stringify('ios'))
  })

  it('works with android platform', () => {
    const config = getPluginConfig({ platform: 'android' })
    expect(config.define['__PLATFORM__']).toBe(JSON.stringify('android'))
  })

  it('works with macos platform', () => {
    const config = getPluginConfig({ platform: 'macos' })
    expect(config.define['__PLATFORM__']).toBe(JSON.stringify('macos'))
  })

  it('treats any non-production mode as development', () => {
    const testConfig = getPluginConfig({}, { mode: 'test' })
    expect(testConfig.define['__DEV__']).toBe(JSON.stringify(true))
    expect(testConfig.build.sourcemap).toBe(true)
    expect(testConfig.build.minify).toBe(false)

    const stagingConfig = getPluginConfig({}, { mode: 'staging' })
    expect(stagingConfig.define['__DEV__']).toBe(JSON.stringify(true))
  })

  it('only treats mode "production" as production', () => {
    const prodConfig = getPluginConfig({}, { mode: 'production' })
    expect(prodConfig.define['__DEV__']).toBe(JSON.stringify(false))
    expect(prodConfig.build.sourcemap).toBe(false)
    expect(prodConfig.build.minify).toBe('esbuild')
  })

  it('accepts all options simultaneously', () => {
    const config = getPluginConfig({
      platform: 'android',
      globalName: 'CustomApp',
      hotReload: false,
      hotReloadPort: 9000,
    })
    expect(config.define['__PLATFORM__']).toBe(JSON.stringify('android'))
    expect(config.build.lib.name).toBe('CustomApp')
  })

  it('config hook receives user config for merging', () => {
    // Ensure the plugin's config hook can access user-provided config
    const userConfig = { build: { lib: { entry: 'custom/entry.ts' } } }
    const config = getPluginConfig({}, { mode: 'production' }, userConfig)
    expect(config.build.lib.entry).toBe('custom/entry.ts')
  })
})

// ---------------------------------------------------------------------------
// Type-level sanity checks (ensure plugin shape matches Vite expectations)
// ---------------------------------------------------------------------------
describe('Plugin shape', () => {
  it('returns an object with name and config properties', () => {
    const plugin = vueNativePlugin()
    const keys = Object.keys(plugin)
    expect(keys).toContain('name')
    expect(keys).toContain('config')
  })

  it('config hook returns an object with resolve, define, and build', () => {
    const config = getPluginConfig()
    expect(config).toHaveProperty('resolve')
    expect(config).toHaveProperty('define')
    expect(config).toHaveProperty('build')
  })

  it('resolve has alias sub-object', () => {
    const config = getPluginConfig()
    expect(config.resolve).toHaveProperty('alias')
    expect(typeof config.resolve.alias).toBe('object')
  })

  it('build has lib, rollupOptions, target, sourcemap, minify, emptyOutDir', () => {
    const config = getPluginConfig()
    expect(config.build).toHaveProperty('lib')
    expect(config.build).toHaveProperty('rollupOptions')
    expect(config.build).toHaveProperty('target')
    expect(config.build).toHaveProperty('sourcemap')
    expect(config.build).toHaveProperty('minify')
    expect(config.build).toHaveProperty('emptyOutDir')
  })
})

// ---------------------------------------------------------------------------
// Real Vite integration
// ---------------------------------------------------------------------------
describe('Vite integration', () => {
  it('rejects globally forced Vapor compilation during Vite configuration', async () => {
    const packageRoot = fileURLToPath(new URL('../..', import.meta.url))
    const tempRoot = await mkdtemp(join(packageRoot, 'tmp-vite-global-vapor-'))

    try {
      await mkdir(join(tempRoot, 'app'), { recursive: true })
      await writeFile(join(tempRoot, 'app', 'main.ts'), 'import \'./App.vue\'\n')
      await writeFile(
        join(tempRoot, 'app', 'App.vue'),
        '<script setup>const message = "Vapor"</script><template><VText>{{ message }}</VText></template>',
      )

      await expect(build({
        root: tempRoot,
        logLevel: 'silent',
        plugins: [
          vue({ script: { vapor: true } } as any),
          vueNativePlugin({
            hotReload: false,
            nativeCodegen: false,
          }),
        ],
      })).rejects.toThrow(/VN_VAPOR_UNSUPPORTED.*script.*vapor/s)
    } finally {
      await rm(tempRoot, { recursive: true, force: true })
    }
  })

  it('rejects Vapor syntax before @vitejs/plugin-vue compiles the SFC', async () => {
    const packageRoot = fileURLToPath(new URL('../..', import.meta.url))
    const tempRoot = await mkdtemp(join(packageRoot, 'tmp-vite-vapor-'))

    try {
      await mkdir(join(tempRoot, 'app'), { recursive: true })
      await writeFile(join(tempRoot, 'app', 'main.ts'), 'import \'./App.vue\'\n')
      await writeFile(
        join(tempRoot, 'app', 'App.vue'),
        '<script setup vapor>const message = "Vapor"</script><template><VText>{{ message }}</VText></template>',
      )

      await expect(build({
        root: tempRoot,
        logLevel: 'silent',
        plugins: [
          vue(),
          vueNativePlugin({
            hotReload: false,
            nativeCodegen: false,
          }),
        ],
      })).rejects.toThrow(/VN_VAPOR_UNSUPPORTED/)
    } finally {
      await rm(tempRoot, { recursive: true, force: true })
    }
  })

  it('builds a Vue Native bundle with the current Vite major', async () => {
    const packageRoot = fileURLToPath(new URL('../..', import.meta.url))
    const runtimeEntry = fileURLToPath(new URL('../../../runtime/src/index.ts', import.meta.url))
    const tempRoot = await mkdtemp(join(packageRoot, 'tmp-vite-plugin-'))

    try {
      await mkdir(join(tempRoot, 'app'), { recursive: true })
      const runtimePackageDir = join(tempRoot, 'node_modules', '@thelacanians', 'vue-native-runtime')
      await mkdir(runtimePackageDir, { recursive: true })
      await writeFile(
        join(runtimePackageDir, 'package.json'),
        JSON.stringify({
          name: '@thelacanians/vue-native-runtime',
          type: 'module',
          exports: {
            '.': './index.ts',
          },
        }, null, 2),
      )
      await writeFile(
        join(runtimePackageDir, 'index.ts'),
        `export * from ${JSON.stringify(pathToFileURL(runtimeEntry).href)}\n`,
      )
      await writeFile(
        join(tempRoot, 'app', 'main.ts'),
        [
          'import { createApp } from \'vue\'',
          'import App from \'./App.vue\'',
          '',
          'createApp(App).start()',
          '',
        ].join('\n'),
      )
      await writeFile(
        join(tempRoot, 'app', 'App.vue'),
        [
          '<template>',
          '  <VView :style="{ flex: 1, padding: 12 }">',
          '    <VText>Hello from Vite 8</VText>',
          '  </VView>',
          '</template>',
          '',
        ].join('\n'),
      )

      await build({
        root: tempRoot,
        logLevel: 'silent',
        plugins: [
          vue(),
          vueNativePlugin({
            hotReload: false,
            nativeCodegen: false,
          }),
        ],
      })

      const bundle = await readFile(join(tempRoot, 'dist', 'vue-native-bundle.js'), 'utf8')
      expect(bundle).toContain('Hello from Vite 8')
      expect(bundle).not.toContain('process.env.NODE_ENV')
    } finally {
      await rm(tempRoot, { recursive: true, force: true })
    }
  })

  it('compiles the authoritative environment target and falls back to the explicit option', async () => {
    const packageRoot = fileURLToPath(new URL('../..', import.meta.url))
    const tempRoot = await mkdtemp(join(packageRoot, 'tmp-vite-platform-'))
    const previousPlatform = process.env.VUE_NATIVE_PLATFORM

    try {
      await mkdir(join(tempRoot, 'app'), { recursive: true })
      await writeFile(
        join(tempRoot, 'app', 'main.ts'),
        [
          'import { ref } from \'@vue/reactivity\'',
          'import { nextTick } from \'@vue/runtime-core\'',
          'globalThis.__vueRuntimeProbe = { ref, nextTick }',
          'globalThis.__compiledPlatform = __PLATFORM__',
          '',
        ].join('\n'),
      )

      process.env.VUE_NATIVE_PLATFORM = 'android'
      await build({
        root: tempRoot,
        logLevel: 'silent',
        plugins: [vueNativePlugin({
          platform: 'macos',
          hotReload: false,
          nativeCodegen: false,
        })],
      })
      let bundle = await readFile(join(tempRoot, 'dist', 'vue-native-bundle.js'), 'utf8')
      expect(bundle).toMatch(/__compiledPlatform\s*=\s*["']android["']/)

      delete process.env.VUE_NATIVE_PLATFORM
      await build({
        root: tempRoot,
        logLevel: 'silent',
        plugins: [vueNativePlugin({
          platform: 'macos',
          hotReload: false,
          nativeCodegen: false,
        })],
      })
      bundle = await readFile(join(tempRoot, 'dist', 'vue-native-bundle.js'), 'utf8')
      expect(bundle).toMatch(/__compiledPlatform\s*=\s*["']macos["']/)
    } finally {
      if (previousPlatform === undefined) delete process.env.VUE_NATIVE_PLATFORM
      else process.env.VUE_NATIVE_PLATFORM = previousPlatform
      await rm(tempRoot, { recursive: true, force: true })
    }
  })
})
