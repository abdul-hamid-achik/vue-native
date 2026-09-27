import { Command } from 'commander'
import { existsSync } from 'node:fs'
import { join } from 'node:path'
import { execFileSync } from 'node:child_process'
import pc from 'picocolors'
import { loadConfig } from '../config.js'
import { p } from '../ui.js'

export interface DoctorCheck {
  id: string
  ok: boolean
  level: 'error' | 'warn' | 'info'
  message: string
}

export interface DoctorReport {
  schemaVersion: 1
  ok: boolean
  cwd: string
  checks: DoctorCheck[]
}

export async function collectDoctorReport(
  cwd: string,
  env: NodeJS.ProcessEnv = process.env,
  host: NodeJS.Platform = process.platform,
): Promise<DoctorReport> {
  const checks: DoctorCheck[] = []

  const hasBun = commandExists('bun')
  checks.push({
    id: 'bun',
    ok: hasBun,
    level: hasBun ? 'info' : 'error',
    message: hasBun ? 'bun is on PATH' : 'bun is not on PATH — install from https://bun.sh',
  })

  const config = await loadConfig(cwd)
  checks.push({
    id: 'config',
    ok: config !== null,
    level: config ? 'info' : 'warn',
    message: config
      ? `Loaded vue-native config for ${config.name}`
      : 'No vue-native.config.{ts,js,mjs} found',
  })

  const ios = existsSync(join(cwd, 'ios'))
  const android = existsSync(join(cwd, 'android'))
  const macos = existsSync(join(cwd, 'macos'))
  checks.push({
    id: 'native.ios',
    ok: ios,
    level: ios ? 'info' : 'warn',
    message: ios ? 'ios/ project present' : 'ios/ directory missing',
  })
  checks.push({
    id: 'native.android',
    ok: android,
    level: android ? 'info' : 'warn',
    message: android ? 'android/ project present' : 'android/ directory missing',
  })
  checks.push({
    id: 'native.macos',
    ok: macos,
    level: macos ? 'info' : 'warn',
    message: macos ? 'macos/ project present' : 'macos/ directory missing (optional unless you target macOS)',
  })

  if (host === 'darwin') {
    const xcode = commandExists('xcodebuild')
    checks.push({
      id: 'xcode',
      ok: xcode,
      level: xcode ? 'info' : 'error',
      message: xcode ? 'xcodebuild is available' : 'xcodebuild not found — install Xcode',
    })

    if (xcode && ios) {
      // `run ios` / `build ios` hard-require XcodeGen to generate the project
      // (native-project.ts ensureXcodeProject), but doctor never checked for it,
      // so it reported a healthy toolchain and the failure surfaced later as a
      // demand to `brew install xcodegen` mid-build.
      const xcodegen = commandExists('xcodegen')
      checks.push({
        id: 'xcodegen',
        ok: xcodegen,
        level: xcodegen ? 'info' : 'error',
        message: xcodegen
          ? 'xcodegen is on PATH'
          : 'xcodegen not found — `vue-native run ios` needs it. Install with: brew install xcodegen',
      })

      // Xcode ships the iOS SDK but NOT a Simulator runtime, and cannot create a
      // device without one. This is an ~8.5 GB one-time download and the single
      // most common first-run blocker; without this check the user only sees
      // "No iOS simulator found" and is told to create one in Xcode, which is
      // impossible until the runtime exists.
      const runtime = iosSimulatorRuntimeState()
      checks.push({
        id: 'iosSimulatorRuntime',
        ok: runtime !== 'missing',
        level: runtime === 'missing' ? 'error' : runtime === 'unknown' ? 'warn' : 'info',
        message: runtime === 'present'
          ? 'An iOS Simulator runtime is installed'
          : runtime === 'unknown'
            ? 'Could not query iOS Simulator runtimes (is Xcode selected via xcode-select?)'
            : 'No iOS Simulator runtime installed. Xcode does not bundle one. '
              + 'Install with: xcodebuild -downloadPlatform iOS   (about 8.5 GB, one time)',
      })
    }
  } else {
    checks.push({
      id: 'xcode',
      ok: true,
      level: 'info',
      message: `Host is ${host}; iOS/macOS builds are not available here`,
    })
  }

  const java = commandExists('java')
  const androidHome = Boolean(env.ANDROID_HOME || env.ANDROID_SDK_ROOT)
  checks.push({
    id: 'java',
    ok: java,
    level: java ? 'info' : 'warn',
    message: java ? 'java is on PATH' : 'java is not on PATH (needed for Android builds)',
  })
  checks.push({
    id: 'androidSdk',
    ok: androidHome,
    level: androidHome ? 'info' : 'warn',
    message: androidHome
      ? 'ANDROID_HOME or ANDROID_SDK_ROOT is set'
      : 'ANDROID_HOME / ANDROID_SDK_ROOT is unset (needed for Android builds)',
  })

  if (android) {
    // `run android` shells out to adb to install and launch, so a missing adb is
    // a hard blocker rather than a nicety. It frequently exists inside an SDK
    // that was never exported to PATH, so look in the usual locations before
    // declaring it absent — reporting "install the SDK" when it is already on
    // disk sends the user on a pointless multi-gigabyte download.
    const adb = resolveAdb(env, host)
    checks.push({
      id: 'adb',
      ok: adb !== null,
      level: adb === null ? 'error' : 'info',
      message: adb === null
        ? 'adb not found on PATH or in a known SDK location — `vue-native run android` '
        + 'cannot install or launch. Install platform-tools, or export ANDROID_HOME.'
        : `adb found at ${adb}`,
    })
  }

  const ok = checks.every(check => check.ok || check.level !== 'error')
  return { schemaVersion: 1, ok, cwd, checks }
}

/** 'present' | 'missing' | 'unknown' (unknown = could not query simctl). */
function iosSimulatorRuntimeState(): 'present' | 'missing' | 'unknown' {
  let raw: string
  try {
    raw = execFileSync('xcrun', ['simctl', 'list', 'runtimes', '--json'], {
      stdio: ['ignore', 'pipe', 'ignore'],
      encoding: 'utf8',
    })
  } catch {
    return 'unknown'
  }

  try {
    const parsed = JSON.parse(raw) as {
      runtimes?: Array<{ platform?: string, isAvailable?: boolean }>
    }
    const iosRuntimes = (parsed.runtimes ?? [])
      .filter(runtime => runtime.platform === 'iOS' && runtime.isAvailable !== false)
    return iosRuntimes.length > 0 ? 'present' : 'missing'
  } catch {
    return 'unknown'
  }
}

/** Absolute path to adb, or null if it cannot be found. */
function resolveAdb(env: NodeJS.ProcessEnv, host: NodeJS.Platform): string | null {
  if (commandExists('adb')) return 'adb (on PATH)'

  const sdkRoots = [
    env.ANDROID_HOME,
    env.ANDROID_SDK_ROOT,
    host === 'darwin' ? join(env.HOME ?? '', 'Library/Android/sdk') : null,
    host === 'darwin' ? '/opt/homebrew/share/android-commandlinetools' : null,
    host === 'win32' ? join(env.LOCALAPPDATA ?? '', 'Android/Sdk') : null,
    host === 'linux' ? join(env.HOME ?? '', 'Android/Sdk') : null,
  ].filter((value): value is string => Boolean(value))

  const executable = host === 'win32' ? 'adb.exe' : 'adb'
  for (const sdkRoot of sdkRoots) {
    const candidate = join(sdkRoot, 'platform-tools', executable)
    if (existsSync(candidate)) return candidate
  }
  return null
}

function commandExists(name: string): boolean {
  try {
    execFileSync(name, ['--version'], { stdio: 'ignore' })
    return true
  } catch {
    try {
      execFileSync(name, ['-version'], { stdio: 'ignore' })
      return true
    } catch {
      return false
    }
  }
}

export const doctorCommand = new Command('doctor')
  .description('Diagnose toolchain, config, and native project health')
  .option('--json', 'print a machine-readable report')
  .action(async (options: { json?: boolean }) => {
    const report = await collectDoctorReport(process.cwd())
    if (options.json) {
      console.log(JSON.stringify(report, null, 2))
    } else {
      p.intro(pc.cyan('Vue Native — doctor'))
      for (const check of report.checks) {
        const icon = check.ok ? pc.green('ok') : check.level === 'error' ? pc.red('err') : pc.yellow('warn')
        console.log(`  [${icon}] ${check.id}: ${check.message}`)
      }
      p.outro(report.ok ? pc.green('No blocking problems') : pc.red('Doctor found errors'))
    }
    if (!report.ok) {
      process.exitCode = 1
    }
  })
