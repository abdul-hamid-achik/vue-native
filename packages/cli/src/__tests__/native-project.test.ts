/**
 * Unit tests for native-project helpers: Gradle failure surfacing, the
 * cross-platform Gradle wrapper resolver, the iOS/macOS host guard, and
 * config-vs-native-project drift detection.
 */
import { describe, it, expect, afterEach } from 'vitest'
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import {
  ensureApplePlatformSupported,
  findAndroidConfigDrift,
  findIOSConfigDrift,
  formatGradleFailure,
  resolveGradleWrapper,
} from '../native-project'
import { ConfigError } from '../config'

describe('formatGradleFailure', () => {
  it('extracts the "What went wrong" block up to the "Try" section', () => {
    const stderr = [
      'Starting a Gradle Daemon',
      'FAILURE: Build failed with an exception.',
      '',
      '* What went wrong:',
      'SDK location not found. Define a valid location in the ANDROID_HOME',
      'environment variable or in sdk.dir in local.properties.',
      '',
      '* Try:',
      '> Run with --stacktrace option to get the stack trace.',
      '',
      'BUILD FAILED in 2s',
    ].join('\n')

    const result = formatGradleFailure(stderr)
    expect(result).toContain('* What went wrong:')
    expect(result).toContain('SDK location not found')
    expect(result).not.toContain('Run with --stacktrace')
    expect(result).not.toContain('BUILD FAILED')
  })

  it('keeps the block to the end when there is no "Try" section', () => {
    const stderr = [
      'FAILURE: Build failed with an exception.',
      '',
      '* What went wrong:',
      'A problem occurred evaluating root project.',
    ].join('\n')

    const result = formatGradleFailure(stderr)
    expect(result).toContain('A problem occurred evaluating root project')
  })

  it('falls back to the last lines when no failure block is present', () => {
    const lines = Array.from({ length: 40 }, (_, i) => `line ${i}`)
    const result = formatGradleFailure(lines.join('\n'))
    expect(result).toContain('line 39')
    expect(result).toContain('line 20')
    expect(result).not.toContain('line 0')
  })

  it('returns an empty string for empty stderr', () => {
    expect(formatGradleFailure('')).toBe('')
    expect(formatGradleFailure('   \n  ')).toBe('')
  })
})

describe('resolveGradleWrapper', () => {
  it('resolves the bash wrapper through a shell-less spawn on macOS and Linux', () => {
    expect(resolveGradleWrapper('darwin')).toEqual({
      command: './gradlew',
      fileName: 'gradlew',
      shell: false,
    })
    expect(resolveGradleWrapper('linux')).toEqual({
      command: './gradlew',
      fileName: 'gradlew',
      shell: false,
    })
  })

  it('resolves the .bat wrapper through a shell on Windows', () => {
    expect(resolveGradleWrapper('win32')).toEqual({
      command: 'gradlew.bat',
      fileName: 'gradlew.bat',
      shell: true,
    })
  })

  it('defaults to the running process.platform when none is given', () => {
    const originalPlatform = Object.getOwnPropertyDescriptor(process, 'platform')!
    Object.defineProperty(process, 'platform', { value: 'win32', configurable: true })
    try {
      expect(resolveGradleWrapper()).toEqual({
        command: 'gradlew.bat',
        fileName: 'gradlew.bat',
        shell: true,
      })
    } finally {
      Object.defineProperty(process, 'platform', originalPlatform)
    }
  })
})

describe('ensureApplePlatformSupported', () => {
  it('never blocks Android builds, regardless of host platform', () => {
    expect(() => ensureApplePlatformSupported('android', 'win32')).not.toThrow()
    expect(() => ensureApplePlatformSupported('android', 'linux')).not.toThrow()
    expect(() => ensureApplePlatformSupported('android', 'darwin')).not.toThrow()
  })

  it('allows iOS/macOS builds on darwin', () => {
    expect(() => ensureApplePlatformSupported('ios', 'darwin')).not.toThrow()
    expect(() => ensureApplePlatformSupported('macos', 'darwin')).not.toThrow()
  })

  it('rejects iOS/macOS builds on non-darwin hosts with an actionable message', () => {
    expect(() => ensureApplePlatformSupported('ios', 'linux')).toThrow(ConfigError)
    expect(() => ensureApplePlatformSupported('ios', 'linux')).toThrow(
      /requires Xcode on macOS.*running on linux.*only Android builds/s,
    )
    expect(() => ensureApplePlatformSupported('macos', 'win32')).toThrow(
      /requires Xcode on macOS.*running on win32/s,
    )
  })

  it('defaults to the running process.platform when none is given', () => {
    const originalPlatform = Object.getOwnPropertyDescriptor(process, 'platform')!
    Object.defineProperty(process, 'platform', { value: 'linux', configurable: true })
    try {
      expect(() => ensureApplePlatformSupported('ios')).toThrow(ConfigError)
    } finally {
      Object.defineProperty(process, 'platform', originalPlatform)
    }
  })
})

describe('config drift detection', () => {
  let root: string

  afterEach(async () => {
    if (root) await rm(root, { recursive: true, force: true })
  })

  describe('findAndroidConfigDrift', () => {
    it('returns no warnings when the native build file matches the config', async () => {
      root = await mkdtemp(join(tmpdir(), 'vue-native-drift-'))
      const androidDir = join(root, 'android')
      await mkdir(join(androidDir, 'app'), { recursive: true })
      await writeFile(
        join(androidDir, 'app', 'build.gradle.kts'),
        'android {\n    defaultConfig {\n        minSdk = 21\n        targetSdk = 35\n    }\n}\n',
      )

      const warnings = findAndroidConfigDrift(androidDir, { minSdk: 21, targetSdk: 35 })
      expect(warnings).toEqual([])
    })

    it('warns when minSdk or targetSdk has drifted from the config', async () => {
      root = await mkdtemp(join(tmpdir(), 'vue-native-drift-'))
      const androidDir = join(root, 'android')
      await mkdir(join(androidDir, 'app'), { recursive: true })
      await writeFile(
        join(androidDir, 'app', 'build.gradle.kts'),
        'android {\n    defaultConfig {\n        minSdk = 21\n        targetSdk = 35\n    }\n}\n',
      )

      const warnings = findAndroidConfigDrift(androidDir, { minSdk: 24, targetSdk: 35 })
      expect(warnings).toHaveLength(1)
      expect(warnings[0]).toContain('android.minSdk=24')
      expect(warnings[0]).toContain('build.gradle.kts uses 21')
      expect(warnings[0]).toContain('native project files are the source of truth')
    })

    it('reports both minSdk and targetSdk drift independently', async () => {
      root = await mkdtemp(join(tmpdir(), 'vue-native-drift-'))
      const androidDir = join(root, 'android')
      await mkdir(join(androidDir, 'app'), { recursive: true })
      await writeFile(
        join(androidDir, 'app', 'build.gradle.kts'),
        'android {\n    defaultConfig {\n        minSdk = 21\n        targetSdk = 33\n    }\n}\n',
      )

      const warnings = findAndroidConfigDrift(androidDir, { minSdk: 24, targetSdk: 35 })
      expect(warnings).toHaveLength(2)
      expect(warnings.some(w => w.includes('android.minSdk=24'))).toBe(true)
      expect(warnings.some(w => w.includes('android.targetSdk=35'))).toBe(true)
    })

    it('returns no warnings when the build file does not exist', async () => {
      root = await mkdtemp(join(tmpdir(), 'vue-native-drift-'))
      const androidDir = join(root, 'android')

      const warnings = findAndroidConfigDrift(androidDir, { minSdk: 21, targetSdk: 35 })
      expect(warnings).toEqual([])
    })
  })

  describe('findIOSConfigDrift', () => {
    it('returns no warnings when project.yml matches the config', async () => {
      root = await mkdtemp(join(tmpdir(), 'vue-native-drift-'))
      const iosDir = join(root, 'ios')
      await mkdir(iosDir, { recursive: true })
      await writeFile(
        join(iosDir, 'project.yml'),
        'options:\n  deploymentTarget:\n    iOS: "16.0"\n',
      )

      const warnings = findIOSConfigDrift(iosDir, { deploymentTarget: '16.0' })
      expect(warnings).toEqual([])
    })

    it('warns when deploymentTarget has drifted from the config', async () => {
      root = await mkdtemp(join(tmpdir(), 'vue-native-drift-'))
      const iosDir = join(root, 'ios')
      await mkdir(iosDir, { recursive: true })
      await writeFile(
        join(iosDir, 'project.yml'),
        'options:\n  deploymentTarget:\n    iOS: "15.0"\n',
      )

      const warnings = findIOSConfigDrift(iosDir, { deploymentTarget: '17.0' })
      expect(warnings).toHaveLength(1)
      expect(warnings[0]).toContain('ios.deploymentTarget=17.0')
      expect(warnings[0]).toContain('project.yml uses 15.0')
    })

    it('returns no warnings when project.yml does not exist', async () => {
      root = await mkdtemp(join(tmpdir(), 'vue-native-drift-'))
      const iosDir = join(root, 'ios')

      const warnings = findIOSConfigDrift(iosDir, { deploymentTarget: '16.0' })
      expect(warnings).toEqual([])
    })
  })
})
