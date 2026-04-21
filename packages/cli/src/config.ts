import { existsSync } from 'node:fs'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface VueNativeConfig {
  /** Display name for the app. */
  name: string
  /** Bundle identifier (e.g. com.example.myapp). */
  bundleId: string
  /** App version string (semver). */
  version: string
  /** iOS-specific configuration. */
  ios?: {
    /** Minimum iOS deployment target. Default: "16.0". */
    deploymentTarget?: string
    /** Xcode scheme name (auto-derived from name if omitted). */
    scheme?: string
  }
  /** Android-specific configuration. */
  android?: {
    /** Minimum Android SDK version. Default: 21. */
    minSdk?: number
    /** Target Android SDK version. Default: 34. */
    targetSdk?: number
    /** Android package name (defaults to bundleId). */
    packageName?: string
  }
  /** List of Vue Native plugins to include. */
  plugins?: string[]
}

export interface ResolvedConfig extends VueNativeConfig {
  ios: {
    deploymentTarget: string
    scheme: string
  }
  android: {
    minSdk: number
    targetSdk: number
    packageName: string
  }
  plugins: string[]
}

// ---------------------------------------------------------------------------
// defineConfig helper (for user-land type safety)
// ---------------------------------------------------------------------------

export function defineConfig(config: VueNativeConfig): VueNativeConfig {
  return config
}

export class ConfigError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'ConfigError'
  }
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

function validateConfig(config: unknown): config is VueNativeConfig {
  if (typeof config !== 'object' || config === null) return false
  const c = config as Record<string, unknown>

  if (typeof c.name !== 'string' || c.name.length === 0) {
    throw new ConfigError(
      'Config error: "name" is required and must be a non-empty string.',
    )
  }

  if (
    typeof c.bundleId !== 'string'
    || !/^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$/i.test(c.bundleId)
  ) {
    throw new ConfigError(
      'Config error: "bundleId" must be a valid reverse-domain identifier (e.g. com.example.myapp).',
    )
  }

  if (typeof c.version !== 'string' || c.version.length === 0) {
    throw new ConfigError('Config error: "version" is required (e.g. "1.0.0").')
  }

  if (c.plugins !== undefined) {
    if (!Array.isArray(c.plugins)) {
      throw new ConfigError('Config error: "plugins" must be an array of strings.')
    }
    for (const plugin of c.plugins) {
      if (typeof plugin !== 'string') {
        throw new ConfigError(
          'Config error: "plugins" must be an array of strings.',
        )
      }
    }
  }

  return true
}

// ---------------------------------------------------------------------------
// Loader
// ---------------------------------------------------------------------------

const CONFIG_FILES = [
  'vue-native.config.ts',
  'vue-native.config.js',
  'vue-native.config.mjs',
]

/**
 * Load and resolve the vue-native.config.{ts,js,mjs} file from the project root.
 * Returns null if no config file is found.
 */
export async function loadConfig(cwd: string): Promise<ResolvedConfig | null> {
  let configPath: string | null = null
  for (const filename of CONFIG_FILES) {
    const candidate = join(cwd, filename)
    if (existsSync(candidate)) {
      configPath = candidate
      break
    }
  }

  if (!configPath) return null

  try {
    // Dynamic import works for .mjs and .js files.
    // For .ts files, bun and tsx handle it natively; Node needs a loader.
    const mod = await import(pathToFileURL(configPath).href)
    const raw = mod.default ?? mod

    if (!validateConfig(raw)) {
      throw new ConfigError(`Invalid configuration in ${configPath}`)
    }

    // Resolve defaults
    const config = raw as VueNativeConfig
    const safeName = config.name.replace(/[^a-zA-Z0-9]/g, '')

    const resolved: ResolvedConfig = {
      ...config,
      ios: {
        deploymentTarget: config.ios?.deploymentTarget ?? '16.0',
        scheme: config.ios?.scheme ?? safeName,
      },
      android: {
        minSdk: config.android?.minSdk ?? 21,
        targetSdk: config.android?.targetSdk ?? 34,
        packageName: config.android?.packageName ?? config.bundleId,
      },
      plugins: config.plugins ?? [],
    }

    return resolved
  } catch (err) {
    if (err instanceof ConfigError) throw err
    throw new ConfigError(
      `Failed to load config from ${configPath}: ${(err as Error).message}`,
    )
  }
}
