import { Command } from 'commander'
import { spawn, execSync } from 'node:child_process'
import { existsSync, readdirSync, mkdirSync, copyFileSync } from 'node:fs'
import { join, basename } from 'node:path'
import pc from 'picocolors'

function findXcodeProject(iosDir: string): { path: string, isWorkspace: boolean } | null {
  if (!existsSync(iosDir)) return null

  // Look for .xcworkspace first (CocoaPods), then .xcodeproj
  for (const ext of ['.xcworkspace', '.xcodeproj'] as const) {
    try {
      const entries = readdirSync(iosDir)
      const match = entries.find(e => e.endsWith(ext))
      if (match) {
        return {
          path: join(iosDir, match),
          isWorkspace: ext === '.xcworkspace',
        }
      }
    } catch {}
  }

  return null
}

function findReleaseApk(androidDir: string): string | null {
  const apkDir = join(androidDir, 'app', 'build', 'outputs', 'apk', 'release')
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

function findReleaseAab(androidDir: string): string | null {
  const aabDir = join(androidDir, 'app', 'build', 'outputs', 'bundle', 'release')
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
  .description('Create a release build of the app')
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
      console.error(pc.red('Platform must be "ios", "android", or "macos"'))
      process.exit(1)
    }

    const cwd = process.cwd()
    const outputDir = join(cwd, options.output)

    // Step 1: Build the JS bundle
    const platformLabel = platform === 'ios' ? 'iOS' : platform === 'android' ? 'Android' : 'macOS'
    console.log(pc.cyan(`\n  Vue Native — ${options.mode.charAt(0).toUpperCase() + options.mode.slice(1)} Build (${platformLabel})\n`))
    console.log(pc.white('  Building JS bundle for production...'))
    try {
      execSync('bun run vite build --mode production', { cwd, stdio: 'inherit' })
      console.log(pc.green('  ✓ Bundle built\n'))
    } catch {
      console.error(pc.red('  ✗ Bundle build failed'))
      process.exit(1)
    }

    if (platform === 'ios') {
      buildIOS(cwd, outputDir, options)
    } else if (platform === 'android') {
      buildAndroid(cwd, outputDir, options)
    } else {
      buildMacOS(cwd, outputDir, options)
    }
  })

function buildIOS(
  cwd: string,
  outputDir: string,
  options: {
    mode: string
    scheme?: string
  },
) {
  const iosDir = join(cwd, 'ios')
  const project = findXcodeProject(iosDir)

  if (!project) {
    console.log(pc.yellow('  No Xcode project found in ./ios/'))
    console.log(pc.dim('  To add iOS support, create an Xcode project in the ios/ directory.'))
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

  const xcodebuild = spawn(
    'xcodebuild',
    [
      projectFlag, project.path,
      '-scheme', scheme,
      '-configuration', configuration,
      '-destination', 'generic/platform=iOS',
      '-archivePath', archivePath,
      'archive',
    ],
    {
      cwd,
      stdio: 'pipe',
      env: { ...process.env, DEVELOPER_DIR: '/Applications/Xcode.app/Contents/Developer' },
    },
  )

  // Ensure xcodebuild process is cleaned up on exit or interruption
  const cleanup = () => {
    if (xcodebuild && !xcodebuild.killed) {
      xcodebuild.kill()
    }
  }
  process.on('exit', cleanup)
  process.on('SIGINT', cleanup)
  process.on('SIGTERM', cleanup)

  xcodebuild.stdout?.on('data', (data: Buffer) => {
    const text = data.toString().trim()
    // Show progress indicators from xcodebuild
    if (text.includes('Compiling') || text.includes('Linking') || text.includes('Signing')) {
      console.log(pc.dim(`  ${text.split('\n').pop()}`))
    }
  })

  xcodebuild.stderr?.on('data', (data: Buffer) => {
    const text = data.toString().trim()
    if (text.includes('error:')) {
      console.log(pc.red(`  ${text}`))
    } else if (text.includes('warning:')) {
      console.log(pc.yellow(`  ${text}`))
    }
  })

  xcodebuild.on('error', (err) => {
    console.error(pc.red(`  xcodebuild process error: ${err.message}`))
    cleanup()
  })

  xcodebuild.on('close', (code) => {
    if (code !== 0) {
      console.error(pc.red(`  ✗ Archive failed (exit code ${code})`))
      process.exit(1)
    }

    console.log(pc.green('  ✓ Archive successful\n'))

    if (existsSync(archivePath)) {
      console.log(pc.green(`  Archive: ${archivePath}`))
      console.log(pc.dim('  To export an IPA, open the archive in Xcode Organizer or run:'))
      console.log(pc.dim(`  xcodebuild -exportArchive -archivePath "${archivePath}" -exportOptionsPlist ExportOptions.plist -exportPath "${outputDir}"\n`))
    } else {
      console.log(pc.yellow('  Archive path not found. Check Xcode build settings.\n'))
    }
  })
}

function buildAndroid(
  cwd: string,
  outputDir: string,
  options: {
    aab?: boolean
  },
) {
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
    console.error(pc.red('  ✗ gradlew not found in android/ directory'))
    console.log(pc.dim('  Make sure your Android project has the Gradle wrapper.\n'))
    process.exit(1)
  }

  const gradleTask = options.aab ? 'bundleRelease' : 'assembleRelease'
  const artifactType = options.aab ? 'AAB' : 'APK'

  ensureOutputDir(outputDir)

  console.log(pc.white(`  Building release ${artifactType} with Gradle...`))

  const gradle = spawn(
    './gradlew',
    [gradleTask],
    {
      cwd: androidDir,
      stdio: 'pipe',
      env: { ...process.env },
    },
  )

  // Ensure Gradle process is cleaned up on exit or interruption
  const cleanupGradle = () => {
    if (gradle && !gradle.killed) {
      gradle.kill()
    }
  }
  process.on('exit', cleanupGradle)
  process.on('SIGINT', cleanupGradle)
  process.on('SIGTERM', cleanupGradle)

  gradle.stdout?.on('data', (data: Buffer) => {
    const text = data.toString().trim()
    if (text) {
      console.log(pc.dim(`  ${text}`))
    }
  })

  gradle.stderr?.on('data', (data: Buffer) => {
    const text = data.toString().trim()
    if (text.includes('ERROR') || text.includes('FAILURE')) {
      console.log(pc.red(`  ${text}`))
    }
  })

  gradle.on('error', (err) => {
    console.error(pc.red(`  Gradle process error: ${err.message}`))
    cleanupGradle()
  })

  gradle.on('close', (code) => {
    if (code !== 0) {
      console.error(pc.red(`  ✗ Gradle build failed (exit code ${code})`))
      process.exit(1)
    }

    console.log(pc.green('  ✓ Build successful\n'))

    // Find and copy the artifact to the output directory
    if (options.aab) {
      const aabPath = findReleaseAab(androidDir)
      if (aabPath) {
        const destPath = join(outputDir, basename(aabPath))
        copyFileSync(aabPath, destPath)
        console.log(pc.green(`  AAB copied to: ${destPath}`))
        console.log(pc.dim('  Upload this file to the Google Play Console.\n'))
      } else {
        console.log(pc.yellow('  Could not locate release AAB.'))
        console.log(pc.dim('  Expected at android/app/build/outputs/bundle/release/\n'))
      }
    } else {
      const apkPath = findReleaseApk(androidDir)
      if (apkPath) {
        const destPath = join(outputDir, basename(apkPath))
        copyFileSync(apkPath, destPath)
        console.log(pc.green(`  APK copied to: ${destPath}`))
        console.log(pc.dim('  Install with: adb install -r "' + destPath + '"\n'))
      } else {
        console.log(pc.yellow('  Could not locate release APK.'))
        console.log(pc.dim('  Expected at android/app/build/outputs/apk/release/\n'))
      }
    }
  })
}

function buildMacOS(
  cwd: string,
  outputDir: string,
  options: {
    mode: string
    scheme?: string
  },
) {
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

  const xcodebuild = spawn(
    'xcodebuild',
    [
      projectFlag, project.path,
      '-scheme', scheme,
      '-configuration', configuration,
      '-destination', 'generic/platform=macOS',
      '-archivePath', archivePath,
      'archive',
    ],
    {
      cwd,
      stdio: 'pipe',
      env: { ...process.env, DEVELOPER_DIR: '/Applications/Xcode.app/Contents/Developer' },
    },
  )

  const cleanup = () => {
    if (xcodebuild && !xcodebuild.killed) {
      xcodebuild.kill()
    }
  }
  process.on('exit', cleanup)
  process.on('SIGINT', cleanup)
  process.on('SIGTERM', cleanup)

  xcodebuild.stdout?.on('data', (data: Buffer) => {
    const text = data.toString().trim()
    if (text.includes('Compiling') || text.includes('Linking') || text.includes('Signing')) {
      console.log(pc.dim(`  ${text.split('\n').pop()}`))
    }
  })

  xcodebuild.stderr?.on('data', (data: Buffer) => {
    const text = data.toString().trim()
    if (text.includes('error:')) {
      console.log(pc.red(`  ${text}`))
    } else if (text.includes('warning:')) {
      console.log(pc.yellow(`  ${text}`))
    }
  })

  xcodebuild.on('error', (err) => {
    console.error(pc.red(`  xcodebuild process error: ${err.message}`))
    cleanup()
  })

  xcodebuild.on('close', (code) => {
    if (code !== 0) {
      console.error(pc.red(`  ✗ Archive failed (exit code ${code})`))
      process.exit(1)
    }

    console.log(pc.green('  ✓ Archive successful\n'))

    if (existsSync(archivePath)) {
      console.log(pc.green(`  Archive: ${archivePath}`))
      console.log(pc.dim('  To export a .app or .pkg, open the archive in Xcode Organizer or run:'))
      console.log(pc.dim(`  xcodebuild -exportArchive -archivePath "${archivePath}" -exportOptionsPlist ExportOptions.plist -exportPath "${outputDir}"\n`))
    } else {
      console.log(pc.yellow('  Archive path not found. Check Xcode build settings.\n'))
    }
  })
}
