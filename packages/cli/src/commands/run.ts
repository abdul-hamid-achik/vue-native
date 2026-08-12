import { Command } from 'commander'
import { execFileSync, execSync } from 'node:child_process'
import { existsSync, readdirSync, readFileSync, rmSync, statSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import pc from 'picocolors'
import { ensureBunAvailable } from '../bun-check.js'
import { ConfigError, loadConfig } from '../config.js'
import { runManagedProcess } from '../managed-process.js'
import {
  ensureApplePlatformSupported,
  ensureXcodeProject,
  findAndroidConfigDrift,
  findIOSConfigDrift,
  formatGradleFailure,
  installAndroidBundle,
  readAndroidApplicationId,
  resolveGradleWrapper,
} from '../native-project.js'
import { p, resolvePlatform } from '../ui.js'

const BUN_REQUIRED_MESSAGE = 'Bun is required to build the JS bundle — install it from https://bun.sh and retry.'

const APPLE_BUNDLE_ID_PATTERN = /^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/
const ANDROID_APPLICATION_ID_PATTERN = /^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+$/
const ANDROID_ACTIVITY_PATTERN = /^\.?[A-Za-z_][A-Za-z0-9_$]*(?:\.[A-Za-z_][A-Za-z0-9_$]*)*$/

function validateAppleBundleId(bundleId: string): void {
  if (!APPLE_BUNDLE_ID_PATTERN.test(bundleId)) {
    throw new ConfigError(
      'Invalid iOS bundle identifier. Pass a reverse-domain identifier such as com.example.app.',
    )
  }
}

function validateAndroidComponent(applicationId: string, activity: string): void {
  if (!ANDROID_APPLICATION_ID_PATTERN.test(applicationId)) {
    throw new ConfigError(
      'Invalid Android package name. Pass a reverse-domain identifier such as com.example.app.',
    )
  }
  if (!ANDROID_ACTIVITY_PATTERN.test(activity)) {
    throw new ConfigError(
      'Invalid Android activity name. Use a class name such as .MainActivity or com.example.MainActivity.',
    )
  }
}

function findAppPath(productsSubdir: string): string | null {
  // Look for .app bundle in DerivedData or build directory. `productsSubdir`
  // selects the SDK-specific products folder, e.g. "Debug-iphonesimulator" for
  // simulator builds or "Debug-iphoneos" for physical-device builds.
  const derivedDataBase = join(
    process.env.HOME || '~',
    'Library/Developer/Xcode/DerivedData',
  )

  if (existsSync(derivedDataBase)) {
    try {
      // Sort DerivedData projects by modification time (most recent first) so we
      // pick the app that was just built — readdirSync returns filesystem order
      // (roughly alphabetical), which could select an unrelated project's .app.
      const projects = readdirSync(derivedDataBase)
        .map((name) => {
          try {
            return { name, mtime: statSync(join(derivedDataBase, name)).mtimeMs }
          } catch {
            return { name, mtime: 0 }
          }
        })
        .sort((a, b) => b.mtime - a.mtime)

      for (const { name: project } of projects) {
        const productsDir = join(
          derivedDataBase,
          project,
          'Build/Products',
          productsSubdir,
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
        /<key>CFBundleIdentifier<\/key>\s*<string>([^<]+)<\/string>/,
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
  .argument('[platform]', 'platform to run on (ios, android, macos)')
  .option('--device', 'run on physical device instead of simulator')
  .option('--device-id <udid>', 'UDID of the physical device to target (auto-detected when omitted)')
  .option('--scheme <scheme>', 'Xcode scheme to build')
  .option('--simulator <name>', 'simulator name (auto-detected when omitted)')
  .option('--bundle-id <id>', 'app bundle identifier')
  .option('--package <name>', 'Android package name (auto-detected from app/build.gradle when omitted)')
  .option('--activity <name>', 'Android activity name', '.MainActivity')
  .action(async (platformArg: string | undefined, options: {
    device?: boolean
    deviceId?: string
    scheme?: string
    simulator?: string
    bundleId?: string
    package?: string
    activity: string
  }) => {
    const platform = await resolvePlatform(platformArg)
    ensureApplePlatformSupported(platform)

    const cwd = process.cwd()
    const config = await loadConfig(cwd)
    const resolvedOptions = {
      ...options,
      scheme: options.scheme ?? config?.ios.scheme,
      bundleId: options.bundleId ?? config?.bundleId,
      package: options.package ?? config?.android.packageName,
    }

    // Step 1: Build the JS bundle
    const platformLabel = platform === 'ios' ? 'iOS' : platform === 'android' ? 'Android' : 'macOS'
    p.intro(pc.cyan(`Vue Native — Run ${platformLabel}`))

    // vue-native.config.ts's android/ios settings only apply at scaffold
    // time; warn (but don't auto-sync) when they've since drifted from the
    // native project files, which are authoritative after `create`.
    if (config) {
      const driftWarnings = platform === 'android'
        ? findAndroidConfigDrift(join(cwd, 'android'), config.android)
        : platform === 'ios'
          ? findIOSConfigDrift(join(cwd, 'ios'), config.ios)
          : []
      for (const warning of driftWarnings) {
        p.log.warn(warning)
      }
    }

    p.log.step('Building JS bundle...')
    ensureBunAvailable(BUN_REQUIRED_MESSAGE)
    try {
      execSync('bun run vite build', {
        cwd,
        stdio: 'inherit',
        env: { ...process.env, VUE_NATIVE_PLATFORM: platform },
      })
      p.log.success('Bundle built')
    } catch {
      throw new ConfigError('Bundle build failed')
    }

    if (platform === 'ios') {
      await runIOS(cwd, resolvedOptions)
    } else if (platform === 'android') {
      await runAndroid(cwd, resolvedOptions)
    } else {
      await runMacOS(cwd, resolvedOptions)
    }
  })

/**
 * Pick an iOS simulator: prefer one already booted, otherwise the first
 * available iPhone, otherwise any available device. Returns null if none exist.
 */
function detectIOSSimulator(): string | null {
  try {
    const output = execFileSync(
      'xcrun',
      ['simctl', 'list', 'devices', 'available', '--json'],
      { stdio: 'pipe' },
    ).toString()
    const data = JSON.parse(output) as {
      devices: Record<string, Array<{ name: string, state: string }>>
    }
    const all = Object.values(data.devices).flat()
    const booted = all.find(d => d.state === 'Booted')
    if (booted) return booted.name
    const iphone = all.find(d => d.name.includes('iPhone'))
    if (iphone) return iphone.name
    return all[0]?.name ?? null
  } catch {
    return null
  }
}

interface PhysicalDevice {
  udid: string
  name: string
}

interface DevicectlDevice {
  identifier?: string
  hardwareProperties?: { udid?: string, productType?: string }
  deviceProperties?: { name?: string, udid?: string }
  connectionProperties?: { transportType?: string }
}

interface DevicectlOutput {
  result?: { devices?: DevicectlDevice[] }
  devices?: DevicectlDevice[]
}

/** Flatten an unknown error's message/stderr/stdout into a single searchable string. */
function processErrorText(error: unknown): string {
  const err = error as {
    message?: string
    stderr?: Buffer | string
    stdout?: Buffer | string
  }
  return [err?.message, err?.stderr, err?.stdout]
    .map(value => (typeof value === 'string' ? value : value?.toString?.() ?? ''))
    .join(' ')
}

/** Parse the JSON produced by `xcrun devicectl list devices --json-output`. */
function parseDevicectlDevices(json: string): PhysicalDevice[] {
  let data: DevicectlOutput
  try {
    data = JSON.parse(json) as DevicectlOutput
  } catch {
    return []
  }

  const rawDevices = data?.result?.devices ?? data?.devices ?? []
  if (!Array.isArray(rawDevices)) return []

  const devices: PhysicalDevice[] = []
  for (const device of rawDevices) {
    const udid = device?.hardwareProperties?.udid
      ?? device?.deviceProperties?.udid
      ?? device?.identifier
    if (typeof udid !== 'string' || udid.length === 0) continue

    // devicectl lists paired-but-disconnected devices with a transport other
    // than wired/localNetwork (e.g. "unavailable") — skip those.
    const transport = device?.connectionProperties?.transportType
    if (typeof transport === 'string'
      && transport !== 'wired'
      && transport !== 'localNetwork') {
      continue
    }

    const name = device?.deviceProperties?.name
      ?? device?.hardwareProperties?.productType
      ?? 'iOS device'
    devices.push({ udid, name })
  }
  return devices
}

/**
 * List connected physical iOS devices via `xcrun devicectl` (Xcode 15+).
 * Throws a ConfigError with actionable guidance when devicectl is unavailable
 * or the device list cannot be read.
 */
function listPhysicalDevices(): PhysicalDevice[] {
  const jsonPath = join(tmpdir(), `vue-native-devices-${process.pid}.json`)
  let raw: string
  try {
    execFileSync(
      'xcrun',
      ['devicectl', 'list', 'devices', '--json-output', jsonPath],
      { stdio: 'pipe' },
    )
    raw = readFileSync(jsonPath, 'utf8')
  } catch (error) {
    const text = processErrorText(error)
    if (/devicectl/i.test(text)
      && /(unable to find utility|not a developer tool|could not be found|no such file|ENOENT)/i.test(text)) {
      throw new ConfigError(
        'xcrun devicectl is not available. Install Xcode 15+ to run on a physical device, or install/launch the app via Xcode or ios-deploy.',
      )
    }
    const message = error instanceof Error ? error.message : String(error)
    throw new ConfigError(`Failed to list connected iOS devices: ${message}`)
  } finally {
    try {
      rmSync(jsonPath, { force: true })
    } catch {}
  }

  return parseDevicectlDevices(raw)
}

/**
 * Pick the physical device to target: the one matching --device-id when given,
 * otherwise the first connected device. Throws a clear error when no suitable
 * device is connected.
 */
function selectPhysicalDevice(preferredUdid?: string): PhysicalDevice {
  const devices = listPhysicalDevices()

  if (preferredUdid) {
    const match = devices.find(device => device.udid === preferredUdid)
    if (!match) {
      throw new ConfigError(
        `No connected iOS device matches --device-id ${preferredUdid}. Connect it and trust the computer, then retry.`,
      )
    }
    return match
  }

  if (devices.length === 0) {
    throw new ConfigError(
      'No connected iOS device found. Connect a device and trust the computer, or run without --device to use a simulator.',
    )
  }
  return devices[0]
}

async function runIOS(
  cwd: string,
  options: {
    device?: boolean
    deviceId?: string
    scheme?: string
    simulator?: string
    bundleId?: string
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

  // Build with xcodebuild
  const scheme = options.scheme || project.path.split('/').pop()?.replace(/\.(xcworkspace|xcodeproj)$/, '') || 'App'
  const simulatorName = options.simulator ?? detectIOSSimulator()
  if (!options.device && !simulatorName) {
    throw new ConfigError('No iOS simulator found. Create one in Xcode or pass --simulator <name>.')
  }
  const destination = options.device
    ? 'generic/platform=iOS'
    : `platform=iOS Simulator,name=${simulatorName}`

  const projectFlag = project.isWorkspace ? '-workspace' : '-project'

  console.log(pc.white(`  Building ${scheme} for ${options.device ? 'device' : simulatorName}...`))

  let result
  try {
    result = await runManagedProcess('xcodebuild', [
      projectFlag,
      project.path,
      '-scheme',
      scheme,
      '-destination',
      destination,
      'build',
    ], {
      cwd,
      stdio: 'pipe',
      env: { ...process.env },
    }, {
      stderr: (data) => {
        const text = data.toString().trim()
        if (text.includes('error:') || text.includes('warning:')) {
          console.log(pc.dim(`  ${text}`))
        }
      },
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error(pc.red(`  xcodebuild process error: ${message}`))
    throw new ConfigError(`iOS build process failed: ${message}`)
  }

  if (result.code !== 0) {
    const outcome = result.code === null
      ? `signal ${result.signal ?? 'unknown'}`
      : `exit code ${result.code}`
    console.error(pc.red(`  ✗ Build failed (${outcome})`))
    throw new ConfigError(`iOS build failed with ${outcome}`)
  }

  console.log(pc.green('  ✓ Build successful\n'))

  if (options.device) {
    const bundleId = options.bundleId || readBundleId(join(cwd, 'ios'))
    validateAppleBundleId(bundleId)

    // Resolve the target device first so a missing/untrusted device surfaces a
    // clear error before we go looking for build artifacts.
    const device = selectPhysicalDevice(options.deviceId)

    const appPath = findAppPath('Debug-iphoneos')
    if (!appPath) {
      console.log(pc.yellow('  Could not locate the device .app bundle in DerivedData.'))
      console.log(pc.dim('  The build succeeded — install the app from Xcode directly.\n'))
      return
    }

    console.log(pc.white(`  Installing app on ${device.name}...`))
    try {
      execFileSync(
        'xcrun',
        ['devicectl', 'device', 'install', 'app', '--device', device.udid, appPath],
        { stdio: 'pipe' },
      )
      console.log(pc.green('  ✓ App installed'))
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      console.error(pc.red(`  ✗ Failed to install app: ${message}`))
      throw new ConfigError(`iOS device app install failed: ${message}`)
    }

    console.log(pc.white(`  Launching ${bundleId}...`))
    try {
      execFileSync(
        'xcrun',
        ['devicectl', 'device', 'process', 'launch', '--device', device.udid, bundleId],
        { stdio: 'pipe' },
      )
      console.log(pc.green(`  ✓ App launched on ${device.name}\n`))
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      console.error(pc.red(`  ✗ Failed to launch app: ${message}`))
      throw new ConfigError(`iOS device app launch failed: ${message}`)
    }
    return
  }

  // Launch on simulator
  if (!simulatorName) {
    throw new ConfigError('No iOS simulator found. Create one in Xcode or pass --simulator <name>.')
  }
  const bundleId = options.bundleId || readBundleId(join(cwd, 'ios'))
  validateAppleBundleId(bundleId)

  console.log(pc.white(`  Booting simulator "${simulatorName}"...`))
  try {
    execFileSync('xcrun', ['simctl', 'boot', simulatorName], { stdio: 'pipe' })
  } catch {
    // Ignore error if simulator is already booted
  }

  // Open Simulator.app
  try {
    execFileSync('open', ['-a', 'Simulator'], { stdio: 'pipe' })
  } catch {}

  // Find and install the .app
  const appPath = findAppPath('Debug-iphonesimulator')
  if (appPath) {
    console.log(pc.white(`  Installing app on simulator...`))
    try {
      execFileSync('xcrun', ['simctl', 'install', 'booted', appPath], { stdio: 'pipe' })
      console.log(pc.green('  ✓ App installed'))
    } catch (err) {
      console.error(pc.red(`  ✗ Failed to install app: ${(err as Error).message}`))
      throw new ConfigError(`iOS app install failed: ${(err as Error).message}`)
    }

    console.log(pc.white(`  Launching ${bundleId}...`))
    try {
      execFileSync('xcrun', ['simctl', 'launch', 'booted', bundleId], { stdio: 'pipe' })
      console.log(pc.green(`  ✓ App launched on ${simulatorName}\n`))
    } catch (err) {
      console.error(pc.red(`  ✗ Failed to launch app: ${(err as Error).message}`))
      throw new ConfigError(`iOS app launch failed: ${(err as Error).message}`)
    }
  } else {
    console.log(pc.yellow('  Could not locate .app bundle in DerivedData.'))
    console.log(pc.dim('  Try running the app from Xcode directly.\n'))
  }
}

async function runAndroid(
  cwd: string,
  options: {
    package?: string
    activity: string
  },
): Promise<void> {
  const androidDir = join(cwd, 'android')

  if (!existsSync(androidDir)) {
    console.log(pc.yellow('  No android/ directory found.'))
    console.log(pc.dim('  To add Android support, create an Android project in the android/ directory.'))
    console.log(pc.dim('  Bundle has been built to dist/vue-native-bundle.js\n'))
    return
  }

  // Find the platform-appropriate Gradle wrapper (gradlew.bat on Windows,
  // ./gradlew everywhere else).
  const gradleWrapper = resolveGradleWrapper()
  const gradlewPath = join(androidDir, gradleWrapper.fileName)
  if (!existsSync(gradlewPath)) {
    throw new ConfigError(
      `${gradleWrapper.fileName} not found in android/ directory. Make sure your Android project has the Gradle wrapper.`,
    )
  }

  const applicationId = options.package ?? readAndroidApplicationId(androidDir)
  if (!applicationId) {
    throw new ConfigError(
      'Could not determine the Android applicationId from app/build.gradle. Pass it explicitly with --package.',
    )
  }
  validateAndroidComponent(applicationId, options.activity)

  installAndroidBundle(cwd, androidDir)
  console.log(pc.green('  ✓ JS bundle copied to Android assets'))

  // Build with Gradle
  console.log(pc.white('  Building Android app with Gradle...'))

  // Gradle writes the cause of a failed build to stderr in a `* What went
  // wrong:` block. Capture it so a non-zero exit surfaces the real error.
  let gradleStderr = ''

  let result
  try {
    result = await runManagedProcess(gradleWrapper.command, ['assembleDebug'], {
      cwd: androidDir,
      stdio: 'pipe',
      shell: gradleWrapper.shell,
      env: { ...process.env },
    }, {
      stdout: (data) => {
        const text = data.toString().trim()
        if (text) {
          console.log(pc.dim(`  ${text}`))
        }
      },
      stderr: (data) => {
        const text = data.toString()
        gradleStderr += text
        const trimmed = text.trim()
        if (trimmed.includes('ERROR') || trimmed.includes('FAILURE')) {
          console.log(pc.red(`  ${trimmed}`))
        }
      },
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error(pc.red(`  Gradle process error: ${message}`))
    if (/ENOENT/.test(message)) {
      console.error(pc.yellow(
        '  The Gradle wrapper exists but could not be executed. This usually means the\n'
        + '  shebang interpreter is unavailable (e.g. NixOS has no /usr/bin/env) or the\n'
        + '  file lost its execute bit. Try running it through a shell instead:\n'
        + '    sh android/gradlew assembleDebug',
      ))
    }
    throw new ConfigError(`Android Gradle process failed: ${message}`)
  }

  if (result.code !== 0) {
    const outcome = result.code === null
      ? `signal ${result.signal ?? 'unknown'}`
      : `exit code ${result.code}`
    console.error(pc.red(`  ✗ Gradle build failed (${outcome})`))
    const failure = formatGradleFailure(gradleStderr)
    if (failure) {
      console.error(pc.red(`\n${failure}\n`))
    }
    throw new ConfigError(`Android Gradle build failed with ${outcome}`)
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
    execFileSync('adb', ['install', '-r', apkPath], { stdio: 'pipe' })
    console.log(pc.green('  ✓ APK installed'))
  } catch (err) {
    console.error(pc.red(`  ✗ Failed to install APK: ${(err as Error).message}`))
    console.log(pc.dim('  Make sure an emulator is running or a device is connected (adb devices).\n'))
    throw new ConfigError(`APK install failed: ${(err as Error).message}`)
  }

  // Launch app
  const componentName = `${applicationId}/${options.activity}`
  console.log(pc.white(`  Launching ${componentName}...`))
  try {
    execFileSync('adb', ['shell', 'am', 'start', '-n', componentName], { stdio: 'pipe' })
    console.log(pc.green(`  ✓ App launched\n`))
  } catch (err) {
    console.error(pc.red(`  ✗ Failed to launch app: ${(err as Error).message}`))
    throw new ConfigError(`App launch failed: ${(err as Error).message}`)
  }
}

async function runMacOS(
  cwd: string,
  options: {
    scheme?: string
  },
): Promise<void> {
  const macosDir = join(cwd, 'macos')

  if (!existsSync(macosDir)) {
    console.log(pc.yellow('  No macos/ directory found.'))
    console.log(pc.dim('  To add macOS support, create an Xcode project in the macos/ directory.'))
    console.log(pc.dim('  Bundle has been built to dist/vue-native-bundle.js\n'))
    return
  }

  // Find Xcode project in macos/ directory
  let xcodeProject: string | null = null
  for (const ext of ['.xcworkspace', '.xcodeproj']) {
    try {
      const entries = readdirSync(macosDir)
      const match = entries.find(e => e.endsWith(ext))
      if (match) {
        xcodeProject = join(macosDir, match)
        break
      }
    } catch {}
  }

  if (!xcodeProject) {
    console.log(pc.yellow('  No Xcode project found in ./macos/'))
    return
  }

  const isWorkspace = xcodeProject.endsWith('.xcworkspace')
  const scheme = options.scheme || xcodeProject.split('/').pop()?.replace(/\.(xcworkspace|xcodeproj)$/, '') || 'App'
  const projectFlag = isWorkspace ? '-workspace' : '-project'

  console.log(pc.white(`  Building ${scheme} for macOS...`))

  let result
  try {
    result = await runManagedProcess('xcodebuild', [
      projectFlag,
      xcodeProject,
      '-scheme',
      scheme,
      '-destination',
      'platform=macOS',
      'build',
    ], {
      cwd,
      stdio: 'pipe',
      env: { ...process.env },
    }, {
      stderr: (data) => {
        const text = data.toString().trim()
        if (text.includes('error:') || text.includes('warning:')) {
          console.log(pc.dim(`  ${text}`))
        }
      },
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error(pc.red(`  xcodebuild process error: ${message}`))
    throw new ConfigError(`macOS build process failed: ${message}`)
  }

  if (result.code !== 0) {
    const outcome = result.code === null
      ? `signal ${result.signal ?? 'unknown'}`
      : `exit code ${result.code}`
    console.error(pc.red(`  ✗ Build failed (${outcome})`))
    throw new ConfigError(`macOS build failed with ${outcome}`)
  }

  console.log(pc.green('  ✓ Build successful\n'))

  // Find and launch the macOS app
  const derivedDataBase = join(process.env.HOME || '~', 'Library/Developer/Xcode/DerivedData')
  let appPath: string | null = null

  if (existsSync(derivedDataBase)) {
    try {
      const projects = readdirSync(derivedDataBase)
      for (const project of projects.reverse()) {
        const productsDir = join(derivedDataBase, project, 'Build/Products/Debug')
        if (existsSync(productsDir)) {
          const entries = readdirSync(productsDir)
          const app = entries.find(e => e.endsWith('.app'))
          if (app) {
            appPath = join(productsDir, app)
            break
          }
        }
      }
    } catch {}
  }

  if (appPath) {
    console.log(pc.white(`  Launching ${appPath}...`))
    try {
      execFileSync('open', [appPath], { stdio: 'pipe' })
      console.log(pc.green(`  ✓ App launched\n`))
    } catch (err) {
      console.error(pc.red(`  ✗ Failed to launch app: ${(err as Error).message}`))
      throw new ConfigError(`macOS app launch failed: ${(err as Error).message}`)
    }
  } else {
    console.log(pc.yellow('  Could not locate .app bundle in DerivedData.'))
    console.log(pc.dim('  Try running the app from Xcode directly.\n'))
  }
}
