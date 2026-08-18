import { execFileSync, spawnSync } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { collectAppShellFixtureErrors, loadAppShellFixture } from './app-shell-fixture.mjs'
import {
  iosSimulatorDestination,
  probeAndroidDevices,
  probeIosDevices,
  probeIosSimulators,
} from './host-probes.mjs'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const startedAt = new Date().toISOString()

function git(command) {
  try {
    return execFileSync('git', command, { cwd: root, encoding: 'utf8' }).trim()
  } catch {
    return null
  }
}

function runGate(id, command, args, options = {}) {
  const started = Date.now()
  if (options.skipReason) {
    return {
      id,
      status: 'skipped',
      reason: options.skipReason,
      command: [command, ...args].join(' '),
      durationMs: 0,
    }
  }

  const result = spawnSync(command, args, {
    cwd: options.cwd ?? root,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
    env: { ...process.env, CI: '1' },
  })
  const durationMs = Date.now() - started
  if (result.status === 0) {
    return {
      id,
      status: 'passed',
      command: [command, ...args].join(' '),
      durationMs,
    }
  }
  return {
    id,
    status: 'failed',
    command: [command, ...args].join(' '),
    durationMs,
    exitCode: result.status,
    stderr: (result.stderr || result.stdout || '').slice(-4000),
  }
}

const fixtureErrors = collectAppShellFixtureErrors(loadAppShellFixture())
const iosSim = probeIosSimulators()
const iosDevice = probeIosDevices()
const androidDevice = probeAndroidDevices()

const gates = [
  {
    id: 'fixture',
    status: fixtureErrors.length === 0 ? 'passed' : 'failed',
    command: 'collectAppShellFixtureErrors',
    durationMs: 0,
    errors: fixtureErrors,
  },
  runGate(
    'android.host',
    join(root, 'native', 'android', 'gradlew'),
    [':VueNativeCore:testDebugUnitTest', '--tests', 'com.vuenative.core.AppShellSmokeTest'],
    { cwd: join(root, 'native', 'android') },
  ),
  runGate(
    'macos.host',
    'swift',
    ['test', '--filter', 'AppShellSmokeTests'],
    { cwd: join(root, 'native', 'macos', 'VueNativeMacOS') },
  ),
  runGate(
    'ios.compile',
    'xcodebuild',
    [
      'build-for-testing',
      '-scheme',
      'VueNativeCore',
      '-destination',
      'generic/platform=iOS Simulator',
      'CODE_SIGNING_ALLOWED=NO',
    ],
    {
      cwd: join(root, 'native', 'ios', 'VueNativeCore'),
      skipReason: iosSim.destination
        ? 'Covered by ios.simulator'
        : `${iosSim.skipReason ?? 'No iOS Simulator'}. Install with: bun run ios:ensure-simulator`,
    },
  ),
  runGate(
    'ios.simulator',
    'xcodebuild',
    [
      'test',
      '-scheme',
      'VueNativeCore',
      '-destination',
      iosSimulatorDestination(iosSim),
      '-only-testing:VueNativeCoreTests/AppShellSmokeTests',
    ],
    {
      cwd: join(root, 'native', 'ios', 'VueNativeCore'),
      skipReason: iosSim.skipReason,
    },
  ),
  runGate(
    'ios.device',
    'xcodebuild',
    [
      'test',
      '-scheme',
      'VueNativeCore',
      '-destination',
      iosDevice.destination ?? 'platform=iOS',
      '-only-testing:VueNativeCoreTests/AppShellSmokeTests',
    ],
    {
      cwd: join(root, 'native', 'ios', 'VueNativeCore'),
      skipReason: iosDevice.skipReason,
    },
  ),
  {
    id: 'android.device',
    status: 'skipped',
    reason: androidDevice.skipReason ?? 'Android device UI smoke is not wired yet',
    command: null,
    durationMs: 0,
  },
]

const receipt = {
  schemaVersion: 1,
  kind: 'app-shell-smoke',
  startedAt,
  finishedAt: new Date().toISOString(),
  cwd: root,
  commit: git(['rev-parse', 'HEAD']),
  dirty: Boolean(git(['status', '--porcelain'])),
  probes: {
    iosSimulators: iosSim,
    iosDevices: iosDevice,
    androidDevices: androidDevice,
  },
  gates,
  ok: gates.every(gate => gate.status === 'passed' || gate.status === 'skipped'),
}

const artifactsDir = join(root, 'artifacts')
mkdirSync(artifactsDir, { recursive: true })
const receiptPath = join(artifactsDir, 'app-shell-smoke.json')
writeFileSync(receiptPath, `${JSON.stringify(receipt, null, 2)}\n`)

for (const gate of gates) {
  const icon = gate.status === 'passed' ? 'ok' : gate.status === 'skipped' ? 'skip' : 'fail'
  const extra = gate.reason ? ` (${gate.reason})` : ''
  process.stdout.write(`[${icon}] ${gate.id}${extra}\n`)
}
process.stdout.write(`Wrote ${receiptPath}\n`)

if (!receipt.ok || fixtureErrors.length > 0) {
  process.exitCode = 1
}
