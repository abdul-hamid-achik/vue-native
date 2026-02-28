/**
 * Vite plugin tests — verifies plugin creation, config generation for
 * production and development modes, custom options handling, and edge cases.
 *
 * These tests call plugin hooks directly (the same way Vite itself does)
 * to validate the resolved configuration without needing a real Vite build.
 */
import { describe, it, expect } from 'vitest'
import vueNativePlugin from '../index'
import type { VueNativePluginOptions } from '../index'

// Helper: invoke the plugin's config hook and return the result.
function getPluginConfig(
  pluginOptions?: VueNativePluginOptions,
  env: { mode: string, command?: string } = { mode: 'production' },
  userConfig: Record<string, any> = {},
) {
  const plugin = vueNativePlugin(pluginOptions)
  return plugin.config(userConfig, env as { mode: string })
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

  it('has a config hook', () => {
    const plugin = vueNativePlugin()
    expect(plugin.config).toBeDefined()
    expect(typeof plugin.config).toBe('function')
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

  it('sets inlineDynamicImports to true', () => {
    expect(config.build.rollupOptions.output.inlineDynamicImports).toBe(true)
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

  it('still sets inlineDynamicImports to true', () => {
    expect(config.build.rollupOptions.output.inlineDynamicImports).toBe(true)
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
})

// ---------------------------------------------------------------------------
// Platform option
// ---------------------------------------------------------------------------
describe('Config — platform option', () => {
  it('defaults __PLATFORM__ to "ios"', () => {
    const config = getPluginConfig()
    expect(config.define['__PLATFORM__']).toBe(JSON.stringify('ios'))
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
    const config = plugin.config({}, { mode: 'production' })
    expect(config).toBeDefined()
    expect(config.build).toBeDefined()
    expect(config.resolve).toBeDefined()
    expect(config.define).toBeDefined()
  })

  it('works when called with an empty options object', () => {
    const plugin = vueNativePlugin({})
    const config = plugin.config({}, { mode: 'production' })
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
