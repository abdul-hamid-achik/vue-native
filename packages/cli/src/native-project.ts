import { execSync } from 'node:child_process'
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  statSync,
} from 'node:fs'
import { join } from 'node:path'
import { ConfigError, type ResolvedConfig } from './config.js'

export interface XcodeProject {
  path: string
  isWorkspace: boolean
}

export interface GradleWrapper {
  /** Command to pass to spawn()/runManagedProcess(), relative to androidDir. */
  command: string
  /** File name to check for inside androidDir with existsSync. */
  fileName: string
  /**
   * Whether the command must be spawned through a shell. Windows batch
   * scripts (gradlew.bat) cannot be exec'd directly by Node's spawn() —
   * neither PATHEXT resolution nor .bat execution happens without a shell.
   */
  shell: boolean
}

/**
 * Resolve how to invoke the Gradle wrapper for the current platform.
 *
 * On Windows, spawning `./gradlew` (a bash script) always fails with ENOENT
 * — there is no bash interpreter wired up, and Node's spawn() does not
 * consult PATHEXT for paths that contain a separator. The wrapper shipped
 * for Windows is `gradlew.bat`, which in turn cannot be exec'd directly by
 * spawn() without `shell: true` (Node refuses to CreateProcess a .bat/.cmd
 * file directly as of Node 17+). Every other platform keeps using the bash
 * wrapper with a plain, shell-less spawn.
 */
export function resolveGradleWrapper(
  platform: NodeJS.Platform = process.platform,
): GradleWrapper {
  if (platform === 'win32') {
    return { command: 'gradlew.bat', fileName: 'gradlew.bat', shell: true }
  }
  return { command: './gradlew', fileName: 'gradlew', shell: false }
}

/**
 * Guard iOS/macOS builds so they fail fast with an actionable message on
 * platforms where Xcode cannot exist, instead of surfacing a confusing
 * "brew install xcodegen" error from deep inside ensureXcodeProject.
 */
export function ensureApplePlatformSupported(
  platform: 'ios' | 'android' | 'macos',
  currentPlatform: NodeJS.Platform = process.platform,
): void {
  if (platform === 'android') return
  if (currentPlatform === 'darwin') return
  throw new ConfigError(
    `Building for iOS/macOS requires Xcode on macOS. You are running on ${currentPlatform}; only Android builds are available here.`,
  )
}

/** Find an already-generated Xcode project, preferring workspaces. */
export function findXcodeProject(iosDir: string): XcodeProject | null {
  if (!existsSync(iosDir)) return null

  for (const ext of ['.xcworkspace', '.xcodeproj'] as const) {
    try {
      const match = readdirSync(iosDir).find(entry => entry.endsWith(ext))
      if (match) {
        return {
          path: join(iosDir, match),
          isWorkspace: ext === '.xcworkspace',
        }
      }
    } catch {
      return null
    }
  }

  return null
}

export interface FindAppleAppOptions {
  productsSubdir: string
  scheme?: string
  derivedDataBase?: string
}

/**
 * Locate a built .app in Xcode DerivedData.
 *
 * Projects are sorted by modification time (newest first) so a just-built
 * app wins over leftover products from other checkouts. When `scheme` is
 * set, only `{scheme}.app` is accepted — otherwise the newest products
 * directory's first .app is used.
 */
export function findAppleAppBundle(options: FindAppleAppOptions): string | null {
  const derivedDataBase = options.derivedDataBase
    ?? join(process.env.HOME || '~', 'Library/Developer/Xcode/DerivedData')

  if (!existsSync(derivedDataBase)) return null

  try {
    const projects = readdirSync(derivedDataBase)
      .map((name) => {
        try {
          return { name, mtime: statSync(join(derivedDataBase, name)).mtimeMs }
        } catch {
          return { name, mtime: 0 }
        }
      })
      .sort((a, b) => b.mtime - a.mtime)

    const expectedApp = options.scheme ? `${options.scheme}.app` : null

    for (const { name: project } of projects) {
      const productsDir = join(
        derivedDataBase,
        project,
        'Build/Products',
        options.productsSubdir,
      )
      if (!existsSync(productsDir)) continue

      const apps = readdirSync(productsDir).filter(entry => entry.endsWith('.app'))
      if (apps.length === 0) continue

      if (expectedApp) {
        if (apps.includes(expectedApp)) {
          return join(productsDir, expectedApp)
        }
        continue
      }

      return join(productsDir, apps[0])
    }
  } catch {
    return null
  }

  return null
}

/** Suffix for native-input errors so agents know JS-only success is explicit. */
export function bundleOnlyHint(detail: string): string {
  return `${detail} The JS bundle is at dist/vue-native-bundle.js. Pass --bundle-only to stop after the JS bundle.`
}

/**
 * Return an Xcode project, generating the scaffolded project.yml with XcodeGen
 * when necessary.
 */
export function ensureXcodeProject(iosDir: string): XcodeProject | null {
  const existing = findXcodeProject(iosDir)
  if (existing) return existing

  const specPath = join(iosDir, 'project.yml')
  if (!existsSync(specPath)) return null

  try {
    execSync('xcodegen --version', { cwd: iosDir, stdio: 'ignore' })
  } catch {
    throw new ConfigError(
      'XcodeGen is required to generate ios/project.yml. Install it with `brew install xcodegen`, then retry.',
    )
  }

  try {
    execSync('xcodegen generate', { cwd: iosDir, stdio: 'inherit' })
  } catch (error) {
    throw new ConfigError(
      `Failed to generate the iOS project with XcodeGen: ${(error as Error).message}`,
    )
  }

  const generated = findXcodeProject(iosDir)
  if (!generated) {
    throw new ConfigError(
      'XcodeGen completed, but no .xcodeproj or .xcworkspace was created in ios/.',
    )
  }

  return generated
}

/** Copy the freshly-built JavaScript bundle into the Android app assets. */
export function installAndroidBundle(cwd: string, androidDir: string): string {
  const bundlePath = join(cwd, 'dist', 'vue-native-bundle.js')
  if (!existsSync(bundlePath)) {
    throw new ConfigError(
      'Android bundle not found at dist/vue-native-bundle.js after the Vite build.',
    )
  }

  const assetsDir = join(androidDir, 'app', 'src', 'main', 'assets')
  const destination = join(assetsDir, 'vue-native-bundle.js')
  mkdirSync(assetsDir, { recursive: true })
  copyFileSync(bundlePath, destination)
  return destination
}

/** Read applicationId from a Kotlin or Groovy Android application build file. */
export function readAndroidApplicationId(androidDir: string): string | null {
  for (const filename of ['build.gradle.kts', 'build.gradle']) {
    const buildFile = join(androidDir, 'app', filename)
    if (!existsSync(buildFile)) continue

    try {
      const content = readFileSync(buildFile, 'utf8')
      const match = content.match(/\bapplicationId\s*(?:=\s*)?["']([^"']+)["']/)
      if (match?.[1]) return match[1]
    } catch {
      // Try the next supported build file.
    }
  }

  return null
}

/**
 * Extract the diagnostic section from a failed Gradle build's stderr.
 *
 * Gradle reports the cause of a failure in a `* What went wrong:` block
 * ("SDK location not found...", "Android Gradle plugin requires Java 17...",
 * "You have not accepted the license agreements...", Kotlin compile errors).
 * Surfacing that block — or the tail of the output when the block is absent —
 * turns an opaque non-zero exit code into an actionable error.
 */
export function formatGradleFailure(stderr: string): string {
  const trimmed = stderr.trim()
  if (!trimmed) return ''

  const start = trimmed.indexOf('* What went wrong:')
  if (start !== -1) {
    const rest = trimmed.slice(start)
    const end = rest.indexOf('\n* Try:')
    const block = end === -1 ? rest : rest.slice(0, end)
    return block.trim()
  }

  return trimmed.split('\n').slice(-20).join('\n').trim()
}

const CONFIG_DRIFT_SUFFIX
  = 'native project files are the source of truth after scaffolding; '
    + 'update them manually (see the managed workflow guide).'

/**
 * vue-native.config.ts's android/ios settings are only applied at scaffold
 * time (`vue-native create`); nothing keeps them in sync with the native
 * project files afterward. Detect drift so users are warned instead of
 * silently building with the native files' values while believing the
 * config controls them. This never edits either file — the native project
 * files stay authoritative.
 */
export function findAndroidConfigDrift(
  androidDir: string,
  config: Pick<ResolvedConfig['android'], 'minSdk' | 'targetSdk'>,
): string[] {
  const buildFile = join(androidDir, 'app', 'build.gradle.kts')
  if (!existsSync(buildFile)) return []

  let content: string
  try {
    content = readFileSync(buildFile, 'utf8')
  } catch {
    return []
  }

  const warnings: string[] = []
  const minSdkMatch = content.match(/\bminSdk\s*=\s*(\d+)/)
  if (minSdkMatch) {
    const actual = Number(minSdkMatch[1])
    if (actual !== config.minSdk) {
      warnings.push(
        `vue-native.config.ts sets android.minSdk=${config.minSdk} but android/app/build.gradle.kts uses ${actual} — ${CONFIG_DRIFT_SUFFIX}`,
      )
    }
  }

  const targetSdkMatch = content.match(/\btargetSdk\s*=\s*(\d+)/)
  if (targetSdkMatch) {
    const actual = Number(targetSdkMatch[1])
    if (actual !== config.targetSdk) {
      warnings.push(
        `vue-native.config.ts sets android.targetSdk=${config.targetSdk} but android/app/build.gradle.kts uses ${actual} — ${CONFIG_DRIFT_SUFFIX}`,
      )
    }
  }

  return warnings
}

/**
 * Same idea as {@link findAndroidConfigDrift}, for ios/project.yml's
 * `options.deploymentTarget.iOS`.
 */
export function findIOSConfigDrift(
  iosDir: string,
  config: Pick<ResolvedConfig['ios'], 'deploymentTarget'>,
): string[] {
  const specPath = join(iosDir, 'project.yml')
  if (!existsSync(specPath)) return []

  let content: string
  try {
    content = readFileSync(specPath, 'utf8')
  } catch {
    return []
  }

  const match = content.match(/deploymentTarget:\s*iOS:\s*["']([^"']+)["']/)
  if (!match) return []

  const actual = match[1]
  if (actual === config.deploymentTarget) return []

  return [
    `vue-native.config.ts sets ios.deploymentTarget=${config.deploymentTarget} but ios/project.yml uses ${actual} — ${CONFIG_DRIFT_SUFFIX}`,
  ]
}
