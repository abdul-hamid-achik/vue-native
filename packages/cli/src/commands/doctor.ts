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

  const ok = checks.every(check => check.ok || check.level !== 'error')
  return { schemaVersion: 1, ok, cwd, checks }
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
