import { Command } from 'commander'
import { execSync } from 'node:child_process'
import { existsSync, readdirSync, mkdirSync, copyFileSync } from 'node:fs'
import { join, basename } from 'node:path'
import pc from 'picocolors'
import { ConfigError, loadConfig } from '../config.js'
import { runManagedProcess } from '../managed-process.js'
import { ensureXcodeProject, findXcodeProject, installAndroidBundle } from '../native-project.js'

type BuildMode = 'debug' | 'release'

function findAndroidApk(androidDir: string, mode: BuildMode): string | null {
  const apkDir = join(androidDir, 'app', 'build', 'outputs', 'apk', mode)
  if (existsSync(apkDir)) {
    try {
      const entries = readdirSync(apkDir)
      const apk = entries.find(e => e.endsWith('.apk') && !e.includes('androidTest'))
      if (apk) {
        return join(apkDir, apk)
      }
    } catch {}
  }
  return null
}

function findAndroidAab(androidDir: string, mode: BuildMode): string | null {
  const aabDir = join(androidDir, 'app', 'build', 'outputs', 'bundle', mode)
  if (existsSync(aabDir)) {
    try {
      const entries = readdirSync(aabDir)
      const aab = entries.find(e => e.endsWith('.aab'))
      if (aab) {
        return join(aabDir, aab)
      }
    } catch {}
  }
  return null
}

function ensureOutputDir(outputPath: string): void {
  if (!existsSync(outputPath)) {
    mkdirSync(outputPath, { recursive: true })
  }
}

export const buildCommand = new Command('build')
  .description('Create a native build of the app')
  .argument('<platform>', 'platform to build for (ios, android, macos)')
  .option('--mode <mode>', 'build mode', 'release')
  .option('--output <path>', 'output directory for the build artifact', './build')
  .option('--scheme <scheme>', 'Xcode scheme to build (iOS only)')
  .option('--aab', 'build Android App Bundle (.aab) instead of APK')
  .action(async (platform: string, options: {
    mode: string
    output: string
    scheme?: string
    aab?: boolean
  }) => {
    if (platform !== 'ios' && platform !== 'android' && platform !== 'macos') {
      throw new ConfigError('Platform must be "ios", "android", or "macos"')
    }
    if (options.mode !== 'debug' && options.mode !== 'release') {
      throw new ConfigError('Build mode must be "debug" or "release"')
    }

    const cwd = process.cwd()
    const config = await loadConfig(cwd)
    const resolvedOptions = {
      ...options,
      mode: options.mode as BuildMode,
      scheme: options.scheme ?? config?.ios.scheme,
    }
    const outputDir = join(cwd, options.output)

    // Step 1: Build the JS bundle
    const platformLabel = platform === 'ios' ? 'iOS' : platform === 'android' ? 'Android' : 'macOS'
    console.log(pc.cyan(`\n  Vue Native — ${options.mode.charAt(0).toUpperCase() + options.mode.slice(1)} Build (${platformLabel})\n`))
    console.log(pc.white('  Building JS bundle for production...'))
    try {
      execSync('bun run vite build --mode production', {
        cwd,
        stdio: 'inherit',
        env: { ...process.env, VUE_NATIVE_PLATFORM: platform },
      })
      console.log(pc.green('  ✓ Bundle built\n'))
    } catch {
      throw new ConfigError('Bundle build failed')
    }

    if (platform === 'ios') {
      await buildIOS(cwd, outputDir, resolvedOptions)
    } else if (platform === 'android') {
      await buildAndroid(cwd, outputDir, resolvedOptions)
    } else {
      await buildMacOS(cwd, outputDir, resolvedOptions)
    }
  })

async function buildIOS(
  cwd: string,
  outputDir: string,
  options: {
    mode: BuildMode
    scheme?: string
  },
): Promise<void> {
  const iosDir = join(cwd, 'ios')
  const project = ensureXcodeProject(iosDir)

  if (!project) {
    console.log(pc.yellow('  No Xcode project found in ./ios/'))
    console.log(pc.dim('  Add ios/project.yml or an .xcodeproj/.xcworkspace, then retry.'))
    console.log(pc.dim('  Bundle has been built to dist/vue-native-bundle.js\n'))
    return
  }

  const projectFlag = project.isWorkspace ? '-workspace' : '-project'
  const scheme = options.scheme || project.path.split('/').pop()?.replace(/\.(xcworkspace|xcodeproj)$/, '') || 'App'
  const configuration = options.mode === 'release' ? 'Release' : 'Debug'
  const archivePath = join(outputDir, `${scheme}.xcarchive`)

  ensureOutputDir(outputDir)

  console.log(pc.white(`  Archiving ${scheme} (${configuration})...`))
  console.log(pc.dim(`  Archive path: ${archivePath}`))

  let result
  try {
    result = await runManagedProcess('xcodebuild', [
      projectFlag, project.path,
      '-scheme', scheme,
      '-configuration', configuration,
      '-destination', 'generic/platform=iOS',
      '-archivePath', archivePath,
      'archive',
    ], {
      cwd,
      stdio: 'pipe',
      env: { ...process.env },
    }, {
      stdout: (data) => {
        const text = data.toString().trim()
        if (text.includes('Compiling') || text.includes('Linking') || text.includes('Signing')) {
          console.log(pc.dim(`  ${text.split('\n').pop()}`))
        }
      },
      stderr: (data) => {
        const text = data.toString().trim()
        if (text.includes('error:')) {
          console.log(pc.red(`  ${text}`))
        } else if (text.includes('warning:')) {
          console.log(pc.yellow(`  ${text}`))
        }
      },
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error(pc.red(`  xcodebuild process error: ${message}`))
    throw new ConfigError(`iOS archive process failed: ${message}`)
  }

  if (result.code !== 0) {
    const outcome = result.code === null
      ? `signal ${result.signal ?? 'unknown'}`
      : `exit code ${result.code}`
    console.error(pc.red(`  ✗ Archive failed (${outcome})`))
    throw new ConfigError(`iOS archive failed with ${outcome}`)
  }

  console.log(pc.green('  ✓ Archive successful\n'))

  if (existsSync(archivePath)) {
    console.log(pc.green(`  Archive: ${archivePath}`))
    console.log(pc.dim('  To export an IPA, open the archive in Xcode Organizer or run:'))
    console.log(pc.dim(`  xcodebuild -exportArchive -archivePath "${archivePath}" -exportOptionsPlist ExportOptions.plist -exportPath "${outputDir}"\n`))
  } else {
    console.log(pc.yellow('  Archive path not found. Check Xcode build settings.\n'))
  }
}

async function buildAndroid(
  cwd: string,
  outputDir: string,
  options: {
    mode: BuildMode
    aab?: boolean
  },
): Promise<void> {
  const androidDir = join(cwd, 'android')

  if (!existsSync(androidDir)) {
    console.log(pc.yellow('  No android/ directory found.'))
    console.log(pc.dim('  To add Android support, create an Android project in the android/ directory.'))
    console.log(pc.dim('  Bundle has been built to dist/vue-native-bundle.js\n'))
    return
  }

  // Find gradlew
  const gradlew = join(androidDir, 'gradlew')
  if (!existsSync(gradlew)) {
    throw new ConfigError(
      'gradlew not found in android/ directory. Make sure your Android project has the Gradle wrapper.',
    )
  }

  installAndroidBundle(cwd, androidDir)
  console.log(pc.green('  ✓ JS bundle copied to Android assets'))

  const buildType = options.mode === 'release' ? 'Release' : 'Debug'
  const gradleTask = `${options.aab ? 'bundle' : 'assemble'}${buildType}`
  const artifactType = options.aab ? 'AAB' : 'APK'

  ensureOutputDir(outputDir)

  console.log(pc.white(`  Building ${options.mode} ${artifactType} with Gradle...`))

  let result
  try {
    result = await runManagedProcess('./gradlew', [gradleTask], {
      cwd: androidDir,
      stdio: 'pipe',
      env: { ...process.env },
    }, {
      stdout: (data) => {
        const text = data.toString().trim()
        if (text) {
          console.log(pc.dim(`  ${text}`))
        }
      },
      stderr: (data) => {
        const text = data.toString().trim()
        if (text.includes('ERROR') || text.includes('FAILURE')) {
          console.log(pc.red(`  ${text}`))
        }
      },
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error(pc.red(`  Gradle process error: ${message}`))
    throw new ConfigError(`Android Gradle process failed: ${message}`)
  }

  if (result.code !== 0) {
    const outcome = result.code === null
      ? `signal ${result.signal ?? 'unknown'}`
      : `exit code ${result.code}`
    console.error(pc.red(`  ✗ Gradle build failed (${outcome})`))
    throw new ConfigError(`Android Gradle build failed with ${outcome}`)
  }

  console.log(pc.green('  ✓ Build successful\n'))

  // Find and copy the artifact to the output directory
  if (options.aab) {
    const aabPath = findAndroidAab(androidDir, options.mode)
    if (aabPath) {
      const destPath = join(outputDir, basename(aabPath))
      copyFileSync(aabPath, destPath)
      console.log(pc.green(`  AAB copied to: ${destPath}`))
      console.log(pc.dim('  Upload this file to the Google Play Console.\n'))
    } else {
      console.log(pc.yellow(`  Could not locate ${options.mode} AAB.`))
      console.log(pc.dim(`  Expected at android/app/build/outputs/bundle/${options.mode}/\n`))
    }
  } else {
    const apkPath = findAndroidApk(androidDir, options.mode)
    if (apkPath) {
      const destPath = join(outputDir, basename(apkPath))
      copyFileSync(apkPath, destPath)
      console.log(pc.green(`  APK copied to: ${destPath}`))
      console.log(pc.dim('  Install with: adb install -r "' + destPath + '"\n'))
    } else {
      console.log(pc.yellow(`  Could not locate ${options.mode} APK.`))
      console.log(pc.dim(`  Expected at android/app/build/outputs/apk/${options.mode}/\n`))
    }
  }
}

async function buildMacOS(
  cwd: string,
  outputDir: string,
  options: {
    mode: BuildMode
    scheme?: string
  },
): Promise<void> {
  const macosDir = join(cwd, 'macos')
  const project = findXcodeProject(macosDir)

  if (!project) {
    console.log(pc.yellow('  No Xcode project found in ./macos/'))
    console.log(pc.dim('  To add macOS support, create an Xcode project in the macos/ directory.'))
    console.log(pc.dim('  Bundle has been built to dist/vue-native-bundle.js\n'))
    return
  }

  const projectFlag = project.isWorkspace ? '-workspace' : '-project'
  const scheme = options.scheme || project.path.split('/').pop()?.replace(/\.(xcworkspace|xcodeproj)$/, '') || 'App'
  const configuration = options.mode === 'release' ? 'Release' : 'Debug'
  const archivePath = join(outputDir, `${scheme}.xcarchive`)

  ensureOutputDir(outputDir)

  console.log(pc.white(`  Archiving ${scheme} (${configuration}) for macOS...`))
  console.log(pc.dim(`  Archive path: ${archivePath}`))

  let result
  try {
    result = await runManagedProcess('xcodebuild', [
      projectFlag, project.path,
      '-scheme', scheme,
      '-configuration', configuration,
      '-destination', 'generic/platform=macOS',
      '-archivePath', archivePath,
      'archive',
    ], {
      cwd,
      stdio: 'pipe',
      env: { ...process.env },
    }, {
      stdout: (data) => {
        const text = data.toString().trim()
        if (text.includes('Compiling') || text.includes('Linking') || text.includes('Signing')) {
          console.log(pc.dim(`  ${text.split('\n').pop()}`))
        }
      },
      stderr: (data) => {
        const text = data.toString().trim()
        if (text.includes('error:')) {
          console.log(pc.red(`  ${text}`))
        } else if (text.includes('warning:')) {
          console.log(pc.yellow(`  ${text}`))
        }
      },
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error(pc.red(`  xcodebuild process error: ${message}`))
    throw new ConfigError(`macOS archive process failed: ${message}`)
  }

  if (result.code !== 0) {
    const outcome = result.code === null
      ? `signal ${result.signal ?? 'unknown'}`
      : `exit code ${result.code}`
    console.error(pc.red(`  ✗ Archive failed (${outcome})`))
    throw new ConfigError(`macOS archive failed with ${outcome}`)
  }

  console.log(pc.green('  ✓ Archive successful\n'))

  if (existsSync(archivePath)) {
    console.log(pc.green(`  Archive: ${archivePath}`))
    console.log(pc.dim('  To export a .app or .pkg, open the archive in Xcode Organizer or run:'))
    console.log(pc.dim(`  xcodebuild -exportArchive -archivePath "${archivePath}" -exportOptionsPlist ExportOptions.plist -exportPath "${outputDir}"\n`))
  } else {
    console.log(pc.yellow('  Archive path not found. Check Xcode build settings.\n'))
  }
}
