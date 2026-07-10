import { execSync } from 'node:child_process'
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
} from 'node:fs'
import { join } from 'node:path'
import { ConfigError } from './config.js'

export interface XcodeProject {
  path: string
  isWorkspace: boolean
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
