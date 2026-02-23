import { Command } from 'commander'
import { spawn, execSync } from 'node:child_process'
import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import pc from 'picocolors'

function findAppPath(buildDir: string): string | null {
  // Look for .app bundle in DerivedData or build directory
  const derivedDataBase = join(
    process.env.HOME || '~',
    'Library/Developer/Xcode/DerivedData'
  )

  if (existsSync(derivedDataBase)) {
    try {
      const projects = readdirSync(derivedDataBase)
      // Sort by modification time (most recent first)
      for (const project of projects.reverse()) {
        const productsDir = join(
          derivedDataBase,
          project,
          'Build/Products/Debug-iphonesimulator'
        )
        if (existsSync(productsDir)) {
          const entries = readdirSync(productsDir)
          const app = entries.find(e => e.endsWith('.app'))
          if (app) {
            return join(productsDir, app)
          }
        }
      }
    } catch {}
  }

  return null
}

function readBundleId(iosDir: string): string {
  // Try to read from Info.plist
  const plistPath = join(iosDir, 'Sources', 'Info.plist')
  if (existsSync(plistPath)) {
    try {
      const content = readFileSync(plistPath, 'utf8')
      const match = content.match(
        /<key>CFBundleIdentifier<\/key>\s*<string>([^<]+)<\/string>/
      )
      if (match) {
        return match[1]
      }
    } catch {}
  }
  return 'com.vuenative.app'
}

function findApkPath(androidDir: string): string | null {
  const apkDir = join(androidDir, 'app', 'build', 'outputs', 'apk', 'debug')
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

export const runCommand = new Command('run')
  .description('Build and run the app')
  .argument('<platform>', 'platform to run on (ios, android)')
  .option('--device', 'run on physical device instead of simulator')
  .option('--scheme <scheme>', 'Xcode scheme to build')
  .option('--simulator <name>', 'simulator name', 'iPhone 16')
  .option('--bundle-id <id>', 'app bundle identifier')
  .option('--package <name>', 'Android package name', 'com.vuenative.app')
  .option('--activity <name>', 'Android activity name', '.MainActivity')
  .action(async (platform: string, options: {
    device?: boolean
    scheme?: string
    simulator: string
    bundleId?: string
    package: string
    activity: string
  }) => {
    if (platform !== 'ios' && platform !== 'android') {
      console.error(pc.red('Platform must be "ios" or "android"'))
      process.exit(1)
    }

    const cwd = process.cwd()

    // Step 1: Build the JS bundle
    console.log(pc.cyan(`\n📱 Vue Native — Run ${platform === 'ios' ? 'iOS' : 'Android'}\n`))
    console.log(pc.white('  Building JS bundle...'))
    try {
      execSync('bun run vite build', { cwd, stdio: 'inherit' })
      console.log(pc.green('  ✓ Bundle built\n'))
    } catch {
      console.error(pc.red('  ✗ Bundle build failed'))
      process.exit(1)
    }

    if (platform === 'ios') {
      runIOS(cwd, options)
    } else {
      runAndroid(cwd, options)
    }
  })

function runIOS(
  cwd: string,
  options: {
    device?: boolean
    scheme?: string
    simulator: string
    bundleId?: string
  }
) {
  // Find Xcode project
  let xcodeProject: string | null = null
  const iosDir = join(cwd, 'ios')

  if (existsSync(iosDir)) {
    // Look for .xcworkspace first (CocoaPods), then .xcodeproj
    for (const ext of ['.xcworkspace', '.xcodeproj']) {
      try {
        const entries = readdirSync(iosDir)
        const match = entries.find(e => e.endsWith(ext))
        if (match) {
          xcodeProject = join(iosDir, match)
          break
        }
      } catch {}
    }
  }

  if (!xcodeProject) {
    console.log(pc.yellow('  No Xcode project found in ./ios/'))
    console.log(pc.dim('  To add iOS support, create an Xcode project in the ios/ directory.'))
    console.log(pc.dim('  Bundle has been built to dist/vue-native-bundle.js\n'))
    return
  }

  // Build with xcodebuild
  const isWorkspace = xcodeProject.endsWith('.xcworkspace')
  const scheme = options.scheme || xcodeProject.split('/').pop()?.replace(/\.(xcworkspace|xcodeproj)$/, '') || 'App'
  const destination = options.device
    ? 'generic/platform=iOS'
    : `platform=iOS Simulator,name=${options.simulator}`

  const projectFlag = isWorkspace ? '-workspace' : '-project'

  console.log(pc.white(`  Building ${scheme} for ${options.device ? 'device' : options.simulator}...`))

  const xcodebuild = spawn(
    'xcodebuild',
    [projectFlag, xcodeProject, '-scheme', scheme, '-destination', destination, 'build'],
    {
      cwd,
      stdio: 'pipe',
      env: { ...process.env, DEVELOPER_DIR: '/Applications/Xcode.app/Contents/Developer' },
    }
  )

  xcodebuild.stderr?.on('data', (data: Buffer) => {
    const text = data.toString().trim()
    if (text.includes('error:') || text.includes('warning:')) {
      console.log(pc.dim(`  ${text}`))
    }
  })

  xcodebuild.on('close', (code) => {
    if (code !== 0) {
      console.error(pc.red(`  ✗ Build failed (exit code ${code})`))
      process.exit(1)
    }

    console.log(pc.green('  ✓ Build successful\n'))

    if (options.device) {
      console.log(pc.green('  App built for device. Install via Xcode.\n'))
      return
    }

    // Launch on simulator
    const simulatorName = options.simulator
    const bundleId = options.bundleId || readBundleId(join(cwd, 'ios'))

    console.log(pc.white(`  Booting simulator "${simulatorName}"...`))
    try {
      execSync(`xcrun simctl boot "${simulatorName}"`, { stdio: 'pipe' })
    } catch {
      // Ignore error if simulator is already booted
    }

    // Open Simulator.app
    try {
      execSync('open -a Simulator', { stdio: 'pipe' })
    } catch {}

    // Find and install the .app
    const appPath = findAppPath(join(cwd, 'ios'))
    if (appPath) {
      console.log(pc.white(`  Installing app on simulator...`))
      try {
        execSync(`xcrun simctl install booted "${appPath}"`, { stdio: 'pipe' })
        console.log(pc.green('  ✓ App installed'))
      } catch (err) {
        console.error(pc.red(`  ✗ Failed to install app: ${(err as Error).message}`))
        process.exit(1)
      }

      console.log(pc.white(`  Launching ${bundleId}...`))
      try {
        execSync(`xcrun simctl launch booted "${bundleId}"`, { stdio: 'pipe' })
        console.log(pc.green(`  ✓ App launched on ${simulatorName}\n`))
      } catch (err) {
        console.error(pc.red(`  ✗ Failed to launch app: ${(err as Error).message}`))
        process.exit(1)
      }
    } else {
      console.log(pc.yellow('  Could not locate .app bundle in DerivedData.'))
      console.log(pc.dim('  Try running the app from Xcode directly.\n'))
    }
  })
}

function runAndroid(
  cwd: string,
  options: {
    package: string
    activity: string
  }
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

  // Build with Gradle
  console.log(pc.white('  Building Android app with Gradle...'))

  const gradle = spawn(
    './gradlew',
    ['assembleDebug'],
    {
      cwd: androidDir,
      stdio: 'pipe',
      env: { ...process.env },
    }
  )

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

  gradle.on('close', (code) => {
    if (code !== 0) {
      console.error(pc.red(`  ✗ Gradle build failed (exit code ${code})`))
      process.exit(1)
    }

    console.log(pc.green('  ✓ Build successful\n'))

    // Find APK
    const apkPath = findApkPath(androidDir)
    if (!apkPath) {
      console.log(pc.yellow('  Could not locate debug APK.'))
      console.log(pc.dim('  Expected at android/app/build/outputs/apk/debug/\n'))
      return
    }

    // Install APK
    console.log(pc.white('  Installing APK on device/emulator...'))
    try {
      execSync(`adb install -r "${apkPath}"`, { stdio: 'pipe' })
      console.log(pc.green('  ✓ APK installed'))
    } catch (err) {
      console.error(pc.red(`  ✗ Failed to install APK: ${(err as Error).message}`))
      console.log(pc.dim('  Make sure an emulator is running or a device is connected (adb devices).\n'))
      process.exit(1)
    }

    // Launch app
    const componentName = `${options.package}/${options.activity}`
    console.log(pc.white(`  Launching ${componentName}...`))
    try {
      execSync(`adb shell am start -n "${componentName}"`, { stdio: 'pipe' })
      console.log(pc.green(`  ✓ App launched\n`))
    } catch (err) {
      console.error(pc.red(`  ✗ Failed to launch app: ${(err as Error).message}`))
      process.exit(1)
    }
  })
}
