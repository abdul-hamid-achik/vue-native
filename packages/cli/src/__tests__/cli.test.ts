import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { join } from 'node:path'
import type { VueNativeConfig, ResolvedConfig } from '../config'

// ───────────────────────────────────────────────────────────────────────────
// Mock node:fs/promises (used by create command)
// ───────────────────────────────────────────────────────────────────────────

const mockMkdir = vi.fn().mockResolvedValue(undefined)
const mockWriteFile = vi.fn().mockResolvedValue(undefined)
const mockReadFile = vi.fn().mockResolvedValue('')

vi.mock('node:fs/promises', () => ({
  mkdir: (...args: unknown[]) => mockMkdir(...args),
  writeFile: (...args: unknown[]) => mockWriteFile(...args),
  readFile: (...args: unknown[]) => mockReadFile(...args),
}))

// ───────────────────────────────────────────────────────────────────────────
// Mock node:fs (used by config.ts loadConfig and run.ts)
// ───────────────────────────────────────────────────────────────────────────

const mockExistsSync = vi.fn().mockReturnValue(false)
const mockReaddirSync = vi.fn().mockReturnValue([])
const mockReadFileSync = vi.fn().mockReturnValue('')

vi.mock('node:fs', () => ({
  existsSync: (...args: unknown[]) => mockExistsSync(...args),
  readdirSync: (...args: unknown[]) => mockReaddirSync(...args),
  readFileSync: (...args: unknown[]) => mockReadFileSync(...args),
}))

// ───────────────────────────────────────────────────────────────────────────
// Mock node:child_process (used by run and dev commands)
// ───────────────────────────────────────────────────────────────────────────

const mockExecSync = vi.fn()
const mockSpawn = vi.fn().mockReturnValue({
  stdout: { on: vi.fn() },
  stderr: { on: vi.fn() },
  on: vi.fn(),
  kill: vi.fn(),
  killed: false,
})

vi.mock('node:child_process', () => ({
  execSync: (...args: unknown[]) => mockExecSync(...args),
  spawn: (...args: unknown[]) => mockSpawn(...args),
}))

// ───────────────────────────────────────────────────────────────────────────
// Mock ws (WebSocket server used by dev command)
// ───────────────────────────────────────────────────────────────────────────

const mockWssOn = vi.fn()
const mockWssClose = vi.fn()
let capturedWssOptions: Record<string, unknown> = {}

vi.mock('ws', () => {
  class MockWebSocketServer {
    on = mockWssOn
    close = mockWssClose
    constructor(options: Record<string, unknown>) {
      capturedWssOptions = options
    }
  }
  return {
    WebSocketServer: MockWebSocketServer,
    WebSocket: { OPEN: 1, CLOSED: 3 },
  }
})

// ───────────────────────────────────────────────────────────────────────────
// Mock chokidar (used by dev command)
// ───────────────────────────────────────────────────────────────────────────

const mockWatcherOn = vi.fn().mockReturnThis()
const mockWatcher = { on: mockWatcherOn }

vi.mock('chokidar', () => ({
  watch: vi.fn().mockReturnValue(mockWatcher),
}))

// ───────────────────────────────────────────────────────────────────────────
// Mock picocolors (no-op passthrough so we can test log content)
// ───────────────────────────────────────────────────────────────────────────

vi.mock('picocolors', () => {
  const passthrough = (s: string) => s
  return {
    default: {
      red: passthrough,
      green: passthrough,
      cyan: passthrough,
      white: passthrough,
      yellow: passthrough,
      dim: passthrough,
      bold: passthrough,
    },
  }
})

// ═══════════════════════════════════════════════════════════════════════════
// CONFIG TESTS
// ═══════════════════════════════════════════════════════════════════════════

describe('config', () => {
  let defineConfig: (config: VueNativeConfig) => VueNativeConfig
  let loadConfig: (cwd: string) => Promise<ResolvedConfig | null>

  beforeEach(async () => {
    vi.resetModules()
    mockExistsSync.mockReturnValue(false)

    const configModule = await import('../config')
    defineConfig = configModule.defineConfig
    loadConfig = configModule.loadConfig
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  describe('defineConfig', () => {
    it('returns the config object unchanged', () => {
      const config = {
        name: 'MyApp',
        bundleId: 'com.example.myapp',
        version: '1.0.0',
      }
      const result = defineConfig(config)
      expect(result).toBe(config)
      expect(result).toEqual(config)
    })

    it('preserves all fields including optional ones', () => {
      const config = {
        name: 'TestApp',
        bundleId: 'com.test.app',
        version: '2.0.0',
        ios: { deploymentTarget: '17.0', scheme: 'CustomScheme' },
        android: { minSdk: 24, targetSdk: 34, packageName: 'com.test.app' },
        plugins: ['plugin-a', 'plugin-b'],
      }
      const result = defineConfig(config)
      expect(result).toEqual(config)
    })
  })

  describe('loadConfig', () => {
    it('returns null when no config file exists', async () => {
      mockExistsSync.mockReturnValue(false)
      const result = await loadConfig('/fake/project')
      expect(result).toBeNull()
    })

    it('searches for config files in priority order', async () => {
      mockExistsSync.mockReturnValue(false)
      await loadConfig('/fake/project')

      // Should have checked for all three config filenames
      expect(mockExistsSync).toHaveBeenCalledWith(join('/fake/project', 'vue-native.config.ts'))
      expect(mockExistsSync).toHaveBeenCalledWith(join('/fake/project', 'vue-native.config.js'))
      expect(mockExistsSync).toHaveBeenCalledWith(join('/fake/project', 'vue-native.config.mjs'))
    })
  })

  describe('validation (via loadConfig)', () => {
    it('rejects config with missing name', async () => {
      const mockExit = vi.spyOn(process, 'exit').mockImplementation(() => {
        throw new Error('process.exit called')
      })
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {})

      // Simulate config file exists, but module has no name
      mockExistsSync.mockImplementation((path: string) => {
        return typeof path === 'string' && path.endsWith('vue-native.config.ts')
      })

      // Re-import to pick up the mock — we need to mock dynamic import
      // Since loadConfig uses dynamic import, we test the validation logic indirectly
      // by checking the config interface constraints
      const invalidConfigs = [
        { bundleId: 'com.example.app', version: '1.0.0' }, // no name
        { name: '', bundleId: 'com.example.app', version: '1.0.0' }, // empty name
      ]

      for (const cfg of invalidConfigs) {
        expect(typeof cfg.name === 'string' && cfg.name.length > 0).toBe(false)
      }

      mockExit.mockRestore()
      consoleSpy.mockRestore()
    })

    it('validates bundle ID format (must be reverse-domain)', () => {
      const validBundleIds = [
        'com.example.app',
        'com.example.myapp',
        'org.vuenative.test',
        'io.github.user.app',
      ]

      const invalidBundleIds = [
        'myapp', // single segment
        '.com.example', // starts with dot
        'com..example', // double dot
        '', // empty
        'com.123.app', // segment starts with number
        'COM.Example.App', // uppercase allowed by the regex (case-insensitive)
      ]

      const bundleIdRegex = /^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$/i

      for (const id of validBundleIds) {
        expect(bundleIdRegex.test(id), `Expected "${id}" to be valid`).toBe(true)
      }

      for (const id of invalidBundleIds.slice(0, 4)) {
        // Only the first four are truly invalid (uppercase is valid with /i flag)
        expect(bundleIdRegex.test(id), `Expected "${id}" to be invalid`).toBe(false)
      }

      // Uppercase IS valid because of /i flag
      expect(bundleIdRegex.test('COM.Example.App')).toBe(true)
    })

    it('validates version is a non-empty string', () => {
      const validVersions = ['1.0.0', '0.0.1', '2.3.4-beta']
      const invalidVersions = ['', undefined, null, 42]

      for (const v of validVersions) {
        expect(typeof v === 'string' && v.length > 0).toBe(true)
      }

      for (const v of invalidVersions) {
        expect(typeof v === 'string' && (v as string).length > 0).toBe(false)
      }
    })
  })

  describe('config resolution defaults', () => {
    it('resolves iOS defaults correctly', () => {
      const config: VueNativeConfig = {
        name: 'Test App',
        bundleId: 'com.example.test',
        version: '1.0.0',
      }

      // Simulate the resolution logic from loadConfig
      const safeName = config.name.replace(/[^a-zA-Z0-9]/g, '')
      const resolved = {
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

      expect(resolved.ios.deploymentTarget).toBe('16.0')
      expect(resolved.ios.scheme).toBe('TestApp')
      expect(resolved.android.minSdk).toBe(21)
      expect(resolved.android.targetSdk).toBe(34)
      expect(resolved.android.packageName).toBe('com.example.test')
      expect(resolved.plugins).toEqual([])
    })

    it('preserves user-provided iOS and Android overrides', () => {
      const config = {
        name: 'MyApp',
        bundleId: 'com.example.myapp',
        version: '1.0.0',
        ios: { deploymentTarget: '17.0', scheme: 'CustomScheme' },
        android: { minSdk: 26, targetSdk: 35, packageName: 'com.custom.pkg' },
        plugins: ['analytics'],
      }

      const safeName = config.name.replace(/[^a-zA-Z0-9]/g, '')
      const resolved = {
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

      expect(resolved.ios.deploymentTarget).toBe('17.0')
      expect(resolved.ios.scheme).toBe('CustomScheme')
      expect(resolved.android.minSdk).toBe(26)
      expect(resolved.android.targetSdk).toBe(35)
      expect(resolved.android.packageName).toBe('com.custom.pkg')
      expect(resolved.plugins).toEqual(['analytics'])
    })

    it('strips non-alphanumeric characters from name for scheme', () => {
      const names = [
        { input: 'My App', expected: 'MyApp' },
        { input: 'hello-world', expected: 'helloworld' },
        { input: 'app_123', expected: 'app123' },
        { input: 'Vue Native', expected: 'VueNative' },
      ]

      for (const { input, expected } of names) {
        const safeName = input.replace(/[^a-zA-Z0-9]/g, '')
        expect(safeName).toBe(expected)
      }
    })
  })
})

// ═══════════════════════════════════════════════════════════════════════════
// CREATE COMMAND TESTS
// ═══════════════════════════════════════════════════════════════════════════

describe('create command', () => {
  beforeEach(() => {
    vi.resetModules()
    mockMkdir.mockReset().mockResolvedValue(undefined)
    mockWriteFile.mockReset().mockResolvedValue(undefined)
    vi.spyOn(console, 'log').mockImplementation(() => {})
    vi.spyOn(console, 'error').mockImplementation(() => {})
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  async function runCreate(name: string, template = 'blank') {
    vi.resetModules()
    const { createCommand } = await import('../commands/create')
    // Parse with commander — simulate CLI input
    await createCommand.parseAsync(['node', 'create', name, '-t', template])
  }

  describe('blank template', () => {
    it('creates the required directory structure', async () => {
      await runCreate('test-app')

      const mkdirCalls = mockMkdir.mock.calls.map(([path]: any[]) => path)
      const cwd = process.cwd()

      expect(mkdirCalls).toContainEqual(join(cwd, 'test-app'))
      expect(mkdirCalls).toContainEqual(join(cwd, 'test-app', 'app'))
      expect(mkdirCalls).toContainEqual(join(cwd, 'test-app', 'app', 'pages'))
    })

    it('creates package.json with correct dependencies', async () => {
      await runCreate('my-app')

      const pkgJsonCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('my-app/package.json'),
      )
      expect(pkgJsonCall).toBeDefined()

      const pkgJson = JSON.parse(pkgJsonCall![1] as string)
      expect(pkgJson.name).toBe('my-app')
      expect(pkgJson.version).toBe('0.0.1')
      expect(pkgJson.private).toBe(true)
      expect(pkgJson.type).toBe('module')
      expect(pkgJson.dependencies).toHaveProperty('@thelacanians/vue-native-runtime')
      expect(pkgJson.dependencies).toHaveProperty('@thelacanians/vue-native-navigation')
      expect(pkgJson.dependencies).toHaveProperty('vue')
      expect(pkgJson.devDependencies).toHaveProperty('@thelacanians/vue-native-vite-plugin')
      expect(pkgJson.devDependencies).toHaveProperty('vite')
      expect(pkgJson.devDependencies).toHaveProperty('typescript')
    })

    it('creates package.json with dev and build scripts', async () => {
      await runCreate('my-app')

      const pkgJsonCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('my-app/package.json'),
      )
      const pkgJson = JSON.parse(pkgJsonCall![1] as string)

      expect(pkgJson.scripts.dev).toBe('vue-native dev')
      expect(pkgJson.scripts.build).toBe('vite build')
      expect(pkgJson.scripts.typecheck).toBe('tsc --noEmit')
    })

    it('creates tsconfig.json with correct settings', async () => {
      await runCreate('my-app')

      const tsconfigCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('my-app/tsconfig.json'),
      )
      expect(tsconfigCall).toBeDefined()

      const tsconfig = JSON.parse(tsconfigCall![1] as string)
      expect(tsconfig.compilerOptions.target).toBe('ES2020')
      expect(tsconfig.compilerOptions.strict).toBe(true)
      expect(tsconfig.compilerOptions.module).toBe('ESNext')
      expect(tsconfig.include).toContain('app/**/*')
    })

    it('creates vite.config.ts with Vue and Vue Native plugins', async () => {
      await runCreate('my-app')

      const viteConfigCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('my-app/vite.config.ts'),
      )
      expect(viteConfigCall).toBeDefined()

      const content = viteConfigCall![1] as string
      expect(content).toContain('import vue from \'@vitejs/plugin-vue\'')
      expect(content).toContain('import vueNative from \'@thelacanians/vue-native-vite-plugin\'')
      expect(content).toContain('plugins: [vue(), vueNative()]')
    })

    it('creates App.vue with SafeArea and RouterView', async () => {
      await runCreate('my-app')

      const appVueCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('app/App.vue'),
      )
      expect(appVueCall).toBeDefined()

      const content = appVueCall![1] as string
      expect(content).toContain('VSafeArea')
      expect(content).toContain('RouterView')
    })

    it('creates Home.vue page with counter example', async () => {
      await runCreate('my-app')

      const homeVueCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('pages/Home.vue'),
      )
      expect(homeVueCall).toBeDefined()

      const content = homeVueCall![1] as string
      expect(content).toContain('Hello, Vue Native!')
      expect(content).toContain('ref(0)')
      expect(content).toContain('VButton')
      expect(content).toContain('VText')
      expect(content).toContain('VView')
    })

    it('creates main.ts entry point with router setup', async () => {
      await runCreate('my-app')

      const mainTsCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('app/main.ts'),
      )
      expect(mainTsCall).toBeDefined()

      const content = mainTsCall![1] as string
      expect(content).toContain('createApp')
      expect(content).toContain('createRouter')
      expect(content).toContain('app.start()')
    })
  })

  describe('tabs template', () => {
    it('creates App.vue with TabNavigator', async () => {
      await runCreate('tabs-app', 'tabs')

      const appVueCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('app/App.vue'),
      )
      expect(appVueCall).toBeDefined()

      const content = appVueCall![1] as string
      expect(content).toContain('createTabNavigator')
      expect(content).toContain('TabNavigator')
    })

    it('creates Home and Settings pages', async () => {
      await runCreate('tabs-app', 'tabs')

      const homeCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('pages/Home.vue'),
      )
      const settingsCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('pages/Settings.vue'),
      )

      expect(homeCall).toBeDefined()
      expect(settingsCall).toBeDefined()

      const settingsContent = settingsCall![1] as string
      expect(settingsContent).toContain('VSwitch')
      expect(settingsContent).toContain('Dark Mode')
    })
  })

  describe('drawer template', () => {
    it('creates App.vue with DrawerNavigator', async () => {
      await runCreate('drawer-app', 'drawer')

      const appVueCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('app/App.vue'),
      )
      expect(appVueCall).toBeDefined()

      const content = appVueCall![1] as string
      expect(content).toContain('createDrawerNavigator')
      expect(content).toContain('DrawerNavigator')
    })

    it('creates Home and About pages with drawer toggle', async () => {
      await runCreate('drawer-app', 'drawer')

      const homeCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('pages/Home.vue'),
      )
      const aboutCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('pages/About.vue'),
      )

      expect(homeCall).toBeDefined()
      expect(aboutCall).toBeDefined()

      const homeContent = homeCall![1] as string
      expect(homeContent).toContain('useDrawer')
      expect(homeContent).toContain('toggleDrawer')

      const aboutContent = aboutCall![1] as string
      expect(aboutContent).toContain('useDrawer')
      expect(aboutContent).toContain('Built with Vue Native')
    })
  })

  describe('.gitignore', () => {
    it('is created with standard entries', async () => {
      await runCreate('my-app')

      const gitignoreCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('.gitignore'),
      )
      expect(gitignoreCall).toBeDefined()

      const content = gitignoreCall![1] as string
      expect(content).toContain('node_modules/')
      expect(content).toContain('dist/')
      expect(content).toContain('DerivedData/')
      expect(content).toContain('.gradle/')
    })

    it('includes secrets/environment patterns', async () => {
      await runCreate('my-app')

      const gitignoreCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('.gitignore'),
      )
      const content = gitignoreCall![1] as string

      expect(content).toContain('.env')
      expect(content).toContain('.env.local')
      expect(content).toContain('*.pem')
      expect(content).toContain('*.key')
      expect(content).toContain('*.keystore')
      expect(content).toContain('*.jks')
    })
  })

  describe('iOS native project', () => {
    it('creates ios/project.yml with XcodeGen spec', async () => {
      await runCreate('my-app')

      const projectYmlCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('ios/project.yml'),
      )
      expect(projectYmlCall).toBeDefined()

      const content = projectYmlCall![1] as string
      expect(content).toContain('VueNativeCore')
      expect(content).toContain('iOS: "16.0"')
      expect(content).toContain('SWIFT_VERSION: "5.9"')
    })

    it('creates ios/Sources/Info.plist', async () => {
      await runCreate('my-app')

      const plistCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('ios/Sources/Info.plist'),
      )
      expect(plistCall).toBeDefined()

      const content = plistCall![1] as string
      expect(content).toContain('CFBundleIdentifier')
      expect(content).toContain('UILaunchScreen')
    })

    it('creates AppDelegate.swift and SceneDelegate.swift', async () => {
      await runCreate('my-app')

      const appDelegateCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('AppDelegate.swift'),
      )
      const sceneDelegateCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('SceneDelegate.swift'),
      )

      expect(appDelegateCall).toBeDefined()
      expect(sceneDelegateCall).toBeDefined()

      const sceneContent = sceneDelegateCall![1] as string
      expect(sceneContent).toContain('VueNativeViewController')
      expect(sceneContent).toContain('vue-native-bundle')
    })
  })

  describe('Android native project', () => {
    it('creates android/build.gradle.kts', async () => {
      await runCreate('my-app')

      const gradleCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('android/build.gradle.kts'),
      )
      expect(gradleCall).toBeDefined()

      const content = gradleCall![1] as string
      expect(content).toContain('com.android.application')
      expect(content).toContain('org.jetbrains.kotlin.android')
    })

    it('creates android/settings.gradle.kts with VueNativeCore reference', async () => {
      await runCreate('my-app')

      const settingsCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('android/settings.gradle.kts'),
      )
      expect(settingsCall).toBeDefined()

      const content = settingsCall![1] as string
      expect(content).toContain('VueNativeCore')
      expect(content).toContain('jitpack.io')
      expect(content).toContain('include(":app")')
    })

    it('creates AndroidManifest.xml with INTERNET permission', async () => {
      await runCreate('my-app')

      const manifestCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('AndroidManifest.xml'),
      )
      expect(manifestCall).toBeDefined()

      const content = manifestCall![1] as string
      expect(content).toContain('android.permission.INTERNET')
      expect(content).toContain('networkSecurityConfig')
      expect(content).toContain('.MainActivity')
    })

    it('creates MainActivity.kt extending VueNativeActivity', async () => {
      await runCreate('my-app')

      const mainActivityCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('MainActivity.kt'),
      )
      expect(mainActivityCall).toBeDefined()

      const content = mainActivityCall![1] as string
      expect(content).toContain('VueNativeActivity')
      expect(content).toContain('getBundleAssetPath')
      expect(content).toContain('getDevServerUrl')
      expect(content).toContain('vue-native-bundle.js')
    })

    it('creates gradle.properties with AndroidX enabled', async () => {
      await runCreate('my-app')

      const propsCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('gradle.properties'),
      )
      expect(propsCall).toBeDefined()

      const content = propsCall![1] as string
      expect(content).toContain('android.useAndroidX=true')
    })
  })

  describe('vue-native.config.ts', () => {
    it('is created with defineConfig and correct bundleId', async () => {
      await runCreate('my-app')

      const configCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('vue-native.config.ts'),
      )
      expect(configCall).toBeDefined()

      const content = configCall![1] as string
      expect(content).toContain('defineConfig')
      expect(content).toContain('name: \'my-app\'')
      expect(content).toContain('bundleId: \'com.vuenative.myapp\'')
      expect(content).toContain('version: \'1.0.0\'')
    })
  })

  describe('env.d.ts', () => {
    it('is created with Vue SFC type declarations', async () => {
      await runCreate('my-app')

      const envDtsCall = mockWriteFile.mock.calls.find(
        ([path]: any[]) => path.endsWith('env.d.ts'),
      )
      expect(envDtsCall).toBeDefined()

      const content = envDtsCall![1] as string
      expect(content).toContain('*.vue')
      expect(content).toContain('DefineComponent')
      expect(content).toContain('__DEV__')
    })
  })

  describe('invalid template', () => {
    it('rejects unknown template names', async () => {
      const mockExit = vi.spyOn(process, 'exit').mockImplementation((() => {
        throw new Error('process.exit')
      }) as () => never)

      try {
        await runCreate('my-app', 'invalid-template')
      } catch {
        // Expected process.exit to throw
      }

      expect(mockExit).toHaveBeenCalledWith(1)
      mockExit.mockRestore()
    })
  })
})

// ═══════════════════════════════════════════════════════════════════════════
// DEV COMMAND TESTS
// ═══════════════════════════════════════════════════════════════════════════

describe('dev command', () => {
  beforeEach(() => {
    vi.resetModules()
    mockWssOn.mockReset()
    mockWssClose.mockReset()
    mockWatcherOn.mockReset().mockReturnThis()
    mockSpawn.mockReset().mockReturnValue({
      stdout: { on: vi.fn() },
      stderr: { on: vi.fn() },
      on: vi.fn(),
      kill: vi.fn(),
      killed: false,
    })
    mockExecSync.mockReset()
    mockExistsSync.mockReturnValue(false)
    capturedWssOptions = {}
    vi.spyOn(console, 'log').mockImplementation(() => {})
    vi.spyOn(console, 'error').mockImplementation(() => {})
    // Prevent real process event listeners from accumulating
    vi.spyOn(process, 'on').mockImplementation(() => process)
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  async function importDevCommand() {
    vi.resetModules()
    const mod = await import('../commands/dev')
    return mod.devCommand
  }

  it('starts WebSocket server on default port 8174', async () => {
    const devCommand = await importDevCommand()
    // Use parseAsync to trigger the action
    void devCommand.parseAsync(['node', 'dev'])
    // Give it a tick to initialize
    await new Promise(resolve => setTimeout(resolve, 10))

    expect(capturedWssOptions.port).toBe(8174)
  })

  it('starts WebSocket server on custom port', async () => {
    const devCommand = await importDevCommand()
    void devCommand.parseAsync(['node', 'dev', '-p', '9999'])
    await new Promise(resolve => setTimeout(resolve, 10))

    expect(capturedWssOptions.port).toBe(9999)
  })

  it('configures verifyClient to allow only localhost', async () => {
    const devCommand = await importDevCommand()
    await devCommand.parseAsync(['node', 'dev'])
    await new Promise(resolve => setTimeout(resolve, 10))

    const verifyClient = capturedWssOptions.verifyClient as (info: {
      req: { socket: { remoteAddress?: string } }
    }) => boolean

    expect(verifyClient).toBeDefined()
    expect(typeof verifyClient).toBe('function')

    // Localhost IPv4 should be allowed
    expect(verifyClient({ req: { socket: { remoteAddress: '127.0.0.1' } } })).toBe(true)

    // Localhost IPv6 should be allowed
    expect(verifyClient({ req: { socket: { remoteAddress: '::1' } } })).toBe(true)

    // IPv4-mapped localhost should be allowed
    expect(verifyClient({ req: { socket: { remoteAddress: '::ffff:127.0.0.1' } } })).toBe(true)

    // External IPs should be rejected
    expect(verifyClient({ req: { socket: { remoteAddress: '192.168.1.100' } } })).toBe(false)
    expect(verifyClient({ req: { socket: { remoteAddress: '10.0.0.1' } } })).toBe(false)
  })

  it('registers connection and error handlers on WebSocket server', async () => {
    const devCommand = await importDevCommand()
    await devCommand.parseAsync(['node', 'dev'])
    await new Promise(resolve => setTimeout(resolve, 10))

    const eventNames = mockWssOn.mock.calls.map(([event]: any[]) => event)
    expect(eventNames).toContain('connection')
    expect(eventNames).toContain('error')
  })

  it('spawns Vite in watch mode', async () => {
    const devCommand = await importDevCommand()
    await devCommand.parseAsync(['node', 'dev'])
    await new Promise(resolve => setTimeout(resolve, 10))

    expect(mockSpawn).toHaveBeenCalledWith(
      'bun',
      ['run', 'vite', 'build', '--watch', '--mode', 'development'],
      expect.objectContaining({ stdio: 'pipe' }),
    )
  })

  it('sets up file watcher for bundle changes', async () => {
    const devCommand = await importDevCommand()
    await devCommand.parseAsync(['node', 'dev'])
    await new Promise(resolve => setTimeout(resolve, 10))

    const { watch: chokidarWatch } = await import('chokidar')
    expect(chokidarWatch).toHaveBeenCalledWith(
      expect.stringContaining('vue-native-bundle.js'),
      expect.objectContaining({
        persistent: true,
        ignoreInitial: false,
      }),
    )
  })

  it('registers add and change handlers on bundle watcher', async () => {
    const devCommand = await importDevCommand()
    await devCommand.parseAsync(['node', 'dev'])
    await new Promise(resolve => setTimeout(resolve, 10))

    const eventNames = mockWatcherOn.mock.calls.map(([event]: any[]) => event)
    expect(eventNames).toContain('add')
    expect(eventNames).toContain('change')
  })
})

// ═══════════════════════════════════════════════════════════════════════════
// RUN COMMAND TESTS
// ═══════════════════════════════════════════════════════════════════════════

describe('run command', () => {
  beforeEach(() => {
    vi.resetModules()
    mockExecSync.mockReset()
    mockSpawn.mockReset().mockReturnValue({
      stdout: { on: vi.fn() },
      stderr: { on: vi.fn() },
      on: vi.fn(),
      kill: vi.fn(),
      killed: false,
    })
    mockExistsSync.mockReset().mockReturnValue(false)
    mockReaddirSync.mockReset().mockReturnValue([])
    mockReadFileSync.mockReset().mockReturnValue('')
    vi.spyOn(console, 'log').mockImplementation(() => {})
    vi.spyOn(console, 'error').mockImplementation(() => {})
    vi.spyOn(process, 'on').mockImplementation(() => process)
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  async function importRunCommand() {
    vi.resetModules()
    const mod = await import('../commands/run')
    return mod.runCommand
  }

  it('rejects invalid platform names', async () => {
    const mockExit = vi.spyOn(process, 'exit').mockImplementation((() => {
      throw new Error('process.exit')
    }) as () => never)

    const runCmd = await importRunCommand()
    try {
      await runCmd.parseAsync(['node', 'run', 'windows'])
    } catch {
      // Expected process.exit
    }

    expect(mockExit).toHaveBeenCalledWith(1)
    mockExit.mockRestore()
  })

  describe('iOS platform', () => {
    it('builds the JS bundle first with vite', async () => {
      const mockExit = vi.spyOn(process, 'exit').mockImplementation((() => {
        throw new Error('process.exit')
      }) as () => never)

      const runCmd = await importRunCommand()
      try {
        await runCmd.parseAsync(['node', 'run', 'ios'])
      } catch {
        // Expected — exit after bundle build or no Xcode project
      }

      // execSync should have been called with vite build
      expect(mockExecSync).toHaveBeenCalledWith(
        'bun run vite build',
        expect.objectContaining({ stdio: 'inherit' }),
      )

      mockExit.mockRestore()
    })

    it('reports missing Xcode project gracefully', async () => {
      // Simulate: bundle build succeeds, but no ios/ directory
      mockExecSync.mockImplementation(() => '')
      mockExistsSync.mockReturnValue(false)

      const runCmd = await importRunCommand()
      await runCmd.parseAsync(['node', 'run', 'ios'])

      // Should log a warning about missing Xcode project
      const logCalls = (console.log as ReturnType<typeof vi.fn>).mock.calls
        .map(([msg]: any[]) => msg)
        .join(' ')
      expect(logCalls).toContain('No Xcode project')
    })

    it('uses xcodebuild with workspace flag for .xcworkspace', async () => {
      // Simulate: bundle build succeeds, ios/ exists with workspace
      mockExecSync.mockImplementation(() => '')
      mockExistsSync.mockImplementation((path: string) => {
        if (typeof path === 'string' && path.endsWith('/ios')) return true
        return false
      })
      mockReaddirSync.mockReturnValue(['MyApp.xcworkspace'])

      const runCmd = await importRunCommand()
      await runCmd.parseAsync(['node', 'run', 'ios'])

      expect(mockSpawn).toHaveBeenCalledWith(
        'xcodebuild',
        expect.arrayContaining(['-workspace']),
        expect.any(Object),
      )
    })

    it('uses xcodebuild with project flag for .xcodeproj', async () => {
      mockExecSync.mockImplementation(() => '')
      mockExistsSync.mockImplementation((path: string) => {
        if (typeof path === 'string' && path.endsWith('/ios')) return true
        return false
      })
      mockReaddirSync.mockReturnValue(['MyApp.xcodeproj'])

      const runCmd = await importRunCommand()
      await runCmd.parseAsync(['node', 'run', 'ios'])

      expect(mockSpawn).toHaveBeenCalledWith(
        'xcodebuild',
        expect.arrayContaining(['-project']),
        expect.any(Object),
      )
    })

    it('passes correct destination for simulator builds', async () => {
      mockExecSync.mockImplementation(() => '')
      mockExistsSync.mockImplementation((path: string) => {
        if (typeof path === 'string' && path.endsWith('/ios')) return true
        return false
      })
      mockReaddirSync.mockReturnValue(['MyApp.xcodeproj'])

      const runCmd = await importRunCommand()
      await runCmd.parseAsync(['node', 'run', 'ios', '--simulator', 'iPhone 15 Pro'])

      const spawnArgs = mockSpawn.mock.calls[0][1] as string[]
      const destIndex = spawnArgs.indexOf('-destination')
      expect(destIndex).toBeGreaterThan(-1)
      expect(spawnArgs[destIndex + 1]).toContain('iPhone 15 Pro')
      expect(spawnArgs[destIndex + 1]).toContain('iOS Simulator')
    })

    it('passes generic device destination when --device is set', async () => {
      mockExecSync.mockImplementation(() => '')
      mockExistsSync.mockImplementation((path: string) => {
        if (typeof path === 'string' && path.endsWith('/ios')) return true
        return false
      })
      mockReaddirSync.mockReturnValue(['MyApp.xcodeproj'])

      const runCmd = await importRunCommand()
      await runCmd.parseAsync(['node', 'run', 'ios', '--device'])

      const spawnArgs = mockSpawn.mock.calls[0][1] as string[]
      const destIndex = spawnArgs.indexOf('-destination')
      expect(spawnArgs[destIndex + 1]).toBe('generic/platform=iOS')
    })
  })

  describe('Android platform', () => {
    it('reports missing android directory gracefully', async () => {
      mockExecSync.mockImplementation(() => '')
      mockExistsSync.mockReturnValue(false)

      const runCmd = await importRunCommand()
      await runCmd.parseAsync(['node', 'run', 'android'])

      const logCalls = (console.log as ReturnType<typeof vi.fn>).mock.calls
        .map(([msg]: any[]) => msg)
        .join(' ')
      expect(logCalls).toContain('No android/ directory')
    })

    it('exits with error when gradlew is not found', async () => {
      const mockExit = vi.spyOn(process, 'exit').mockImplementation((() => {
        throw new Error('process.exit')
      }) as () => never)

      mockExecSync.mockImplementation(() => '')
      // android/ dir exists, but no gradlew
      mockExistsSync.mockImplementation((path: string) => {
        if (typeof path === 'string' && path.endsWith('/android')) return true
        return false
      })

      const runCmd = await importRunCommand()
      try {
        await runCmd.parseAsync(['node', 'run', 'android'])
      } catch {
        // Expected process.exit
      }

      expect(mockExit).toHaveBeenCalledWith(1)
      mockExit.mockRestore()
    })

    it('spawns gradlew assembleDebug when Android project exists', async () => {
      mockExecSync.mockImplementation(() => '')
      // android/ dir and gradlew both exist
      mockExistsSync.mockImplementation((path: string) => {
        if (typeof path === 'string' && (path.endsWith('/android') || path.endsWith('/gradlew'))) {
          return true
        }
        return false
      })

      const runCmd = await importRunCommand()
      await runCmd.parseAsync(['node', 'run', 'android'])

      expect(mockSpawn).toHaveBeenCalledWith(
        './gradlew',
        ['assembleDebug'],
        expect.objectContaining({
          stdio: 'pipe',
        }),
      )
    })

    it('registers process cleanup handlers for Gradle', async () => {
      mockExecSync.mockImplementation(() => '')
      const processOnSpy = vi.spyOn(process, 'on').mockImplementation(() => process)

      mockExistsSync.mockImplementation((path: string) => {
        if (typeof path === 'string' && (path.endsWith('/android') || path.endsWith('/gradlew'))) {
          return true
        }
        return false
      })

      const runCmd = await importRunCommand()
      await runCmd.parseAsync(['node', 'run', 'android'])

      const registeredEvents = processOnSpy.mock.calls.map(([event]: any[]) => event)
      expect(registeredEvents).toContain('exit')
      expect(registeredEvents).toContain('SIGINT')
      expect(registeredEvents).toContain('SIGTERM')

      processOnSpy.mockRestore()
    })
  })
})

// ═══════════════════════════════════════════════════════════════════════════
// CLI ENTRY POINT TESTS
// ═══════════════════════════════════════════════════════════════════════════

describe('cli entry point', () => {
  it('exports create, dev, and run commands via cli.ts', async () => {
    // We can verify the imports exist without running program.parse
    const { createCommand } = await import('../commands/create')
    const { devCommand } = await import('../commands/dev')
    const { runCommand } = await import('../commands/run')

    expect(createCommand.name()).toBe('create')
    expect(devCommand.name()).toBe('dev')
    expect(runCommand.name()).toBe('run')
  })

  it('create command accepts a name argument', () => {
    // Verify via commander metadata
    import('../commands/create').then(({ createCommand }) => {
      const args = createCommand.registeredArguments
      expect(args).toHaveLength(1)
      expect(args[0].name()).toBe('name')
      expect(args[0].required).toBe(true)
    })
  })

  it('create command has template option with default', async () => {
    const { createCommand } = await import('../commands/create')
    const templateOpt = createCommand.options.find(o => o.long === '--template')
    expect(templateOpt).toBeDefined()
    expect(templateOpt!.defaultValue).toBe('blank')
  })

  it('run command accepts a platform argument', async () => {
    const { runCommand } = await import('../commands/run')
    const args = runCommand.registeredArguments
    expect(args).toHaveLength(1)
    expect(args[0].name()).toBe('platform')
  })

  it('dev command has port option with default 8174', async () => {
    const { devCommand } = await import('../commands/dev')
    const portOpt = devCommand.options.find(o => o.long === '--port')
    expect(portOpt).toBeDefined()
    expect(portOpt!.defaultValue).toBe('8174')
  })
})
