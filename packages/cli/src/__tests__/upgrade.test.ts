/**
 * `vue-native upgrade` re-vendors the native tree and repoints the JS
 * dependencies. It is deliberately conservative: a project with no version
 * stamp cannot distinguish a stale vendored tree from a locally edited one,
 * and re-vendoring over local edits destroys work, so both cases refuse
 * without --force.
 *
 * These tests shell out to the real CLI rather than importing the command,
 * because the interesting behaviour is the refusal paths and the on-disk
 * result, and cli.test.ts's global fs mocks would hide both.
 */
import { execFileSync } from 'node:child_process'
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync, mkdirSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'

const here = dirname(fileURLToPath(import.meta.url))
const CLI = join(here, '..', 'cli.ts')
const CLI_VERSION = JSON.parse(
  readFileSync(join(here, '..', '..', 'package.json'), 'utf8'),
).version as string

function runUpgrade(cwd: string, args: string[]): { status: number, output: string } {
  try {
    const output = execFileSync('bun', [CLI, 'upgrade', ...args], {
      cwd,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    })
    return { status: 0, output }
  } catch (error) {
    const err = error as { status?: number, stdout?: string, stderr?: string }
    return { status: err.status ?? 1, output: `${err.stdout ?? ''}${err.stderr ?? ''}` }
  }
}

let workspace: string

beforeAll(() => {
  workspace = mkdtempSync(join(tmpdir(), 'vn-upgrade-'))
})

afterAll(() => {
  rmSync(workspace, { recursive: true, force: true })
})

function makeProject(name: string, stamp: object | null): string {
  const dir = join(workspace, name)
  mkdirSync(join(dir, 'native'), { recursive: true })
  writeFileSync(join(dir, 'package.json'), `${JSON.stringify({
    name,
    devDependencies: { '@thelacanians/vue-native-runtime': '^0.20.0' },
  }, null, 2)}\n`)
  if (stamp !== null) {
    writeFileSync(join(dir, 'native', '.vue-native-version'), `${JSON.stringify(stamp)}\n`)
  }
  return dir
}

describe('vue-native upgrade', () => {
  it('refuses outside a Vue Native project', () => {
    const dir = join(workspace, 'not-a-project')
    mkdirSync(dir, { recursive: true })
    const result = runUpgrade(dir, [])
    expect(result.status).not.toBe(0)
    expect(result.output).toContain('does not look like a Vue Native project')
  })

  it('refuses a project with no version stamp unless --force', () => {
    const dir = makeProject('unstamped', null)
    const refused = runUpgrade(dir, [])
    expect(refused.status).not.toBe(0)
    expect(refused.output).toContain('predates version stamping')

    const forced = runUpgrade(dir, ['--force'])
    expect(forced.status).toBe(0)
    const stamp = JSON.parse(readFileSync(join(dir, 'native', '.vue-native-version'), 'utf8'))
    expect(stamp.upgradedFrom).toContain('no stamp')
  })

  it('does nothing when already at the CLI version', () => {
    const dir = makeProject('current', { schema: 1, frameworkVersion: CLI_VERSION })
    const result = runUpgrade(dir, [])
    expect(result.status).toBe(0)
    expect(result.output).toContain('nothing to do')
  })

  it('dry-run reports the plan and writes nothing', () => {
    const dir = makeProject('dry', { schema: 1, frameworkVersion: '0.20.0' })
    const before = readFileSync(join(dir, 'package.json'), 'utf8')
    const stampBefore = readFileSync(join(dir, 'native', '.vue-native-version'), 'utf8')

    const result = runUpgrade(dir, ['--dry-run'])
    expect(result.status).toBe(0)
    expect(result.output).toContain('would re-vendor native/')

    expect(readFileSync(join(dir, 'package.json'), 'utf8')).toBe(before)
    expect(readFileSync(join(dir, 'native', '.vue-native-version'), 'utf8')).toBe(stampBefore)
  })

  it('re-vendors, repoints dependencies and rewrites the stamp', () => {
    const dir = makeProject('real', { schema: 1, frameworkVersion: '0.20.0' })

    const result = runUpgrade(dir, [])
    expect(result.status).toBe(0)

    const pkg = JSON.parse(readFileSync(join(dir, 'package.json'), 'utf8'))
    expect(pkg.devDependencies['@thelacanians/vue-native-runtime']).toBe(`^${CLI_VERSION}`)

    const stamp = JSON.parse(readFileSync(join(dir, 'native', '.vue-native-version'), 'utf8'))
    expect(stamp.frameworkVersion).toBe(CLI_VERSION)
    expect(stamp.upgradedFrom).toBe('0.20.0')

    // The vendored tree actually arrived from the CLI package.
    expect(existsSync(join(dir, 'native', 'ios', 'VueNativeCore', 'Package.swift'))).toBe(true)
  })

  it('wires the optional VSVG add-on into pre-split hosts, idempotently', () => {
    const dir = makeProject('svgwire', { schema: 1, frameworkVersion: '0.20.0' })
    mkdirSync(join(dir, 'ios', 'Sources'), { recursive: true })
    mkdirSync(join(dir, 'macos', 'Sources'), { recursive: true })
    writeFileSync(join(dir, 'ios', 'project.yml'), [
      'packages:',
      '  VueNativeCore:',
      '    path: ../native/ios/VueNativeCore',
      'targets:',
      '  App:',
      '    dependencies:',
      '      - package: VueNativeCore',
      '        product: VueNativeCore',
      '',
    ].join('\n'))
    writeFileSync(join(dir, 'ios', 'Sources', 'AppDelegate.swift'), [
      'import UIKit',
      '',
      '@main',
      'class AppDelegate: UIResponder, UIApplicationDelegate {',
      '    func application(',
      '        _ application: UIApplication,',
      '        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?',
      '    ) -> Bool {',
      '        return true',
      '    }',
      '}',
      '',
    ].join('\n'))
    writeFileSync(join(dir, 'macos', 'project.yml'), [
      'targets:',
      '  App:',
      '    dependencies:',
      '      - package: VueNativeMacOS',
      '        product: VueNativeMacOS',
      '',
    ].join('\n'))
    writeFileSync(join(dir, 'macos', 'Sources', 'AppDelegate.swift'), [
      'import AppKit',
      'import VueNativeMacOS',
      '',
      'class AppDelegate: VueNativeAppDelegate {',
      '    override func applicationDidFinishLaunching(_ notification: Notification) {',
      '        super.applicationDidFinishLaunching(notification)',
      '    }',
      '}',
      '',
    ].join('\n'))

    // Dry run reports the wiring and writes nothing.
    const dry = runUpgrade(dir, ['--dry-run'])
    expect(dry.status).toBe(0)
    expect(dry.output).toContain('would ios/project.yml: link the VueNativeCoreSVG product')
    expect(readFileSync(join(dir, 'ios', 'project.yml'), 'utf8')).not.toContain('VueNativeCoreSVG')

    expect(runUpgrade(dir, []).status).toBe(0)

    const iosYml = readFileSync(join(dir, 'ios', 'project.yml'), 'utf8')
    expect(iosYml).toContain('path: ../native/ios/VueNativeCoreSVG')
    expect(iosYml).toContain('product: VueNativeCoreSVG')
    const iosDelegate = readFileSync(join(dir, 'ios', 'Sources', 'AppDelegate.swift'), 'utf8')
    expect(iosDelegate).toContain('import VueNativeCoreSVG')
    expect(iosDelegate).toContain('VueNativeCoreSVG.register()')

    const macYml = readFileSync(join(dir, 'macos', 'project.yml'), 'utf8')
    expect(macYml).toContain('product: VueNativeMacOSSVG')
    const macDelegate = readFileSync(join(dir, 'macos', 'Sources', 'AppDelegate.swift'), 'utf8')
    expect(macDelegate).toContain('import VueNativeMacOSSVG')
    // register() must run before super, which creates the window controller.
    expect(macDelegate.indexOf('VueNativeMacOSSVG.register()')).toBeLessThan(
      macDelegate.indexOf('super.applicationDidFinishLaunching'),
    )

    // Rewind the stamp so the wiring path runs again: existing markers must
    // not be duplicated.
    const stamp = JSON.parse(readFileSync(join(dir, 'native', '.vue-native-version'), 'utf8'))
    writeFileSync(
      join(dir, 'native', '.vue-native-version'),
      `${JSON.stringify({ ...stamp, frameworkVersion: '0.20.0' }, null, 2)}\n`,
    )
    expect(runUpgrade(dir, []).status).toBe(0)
    const iosYmlAgain = readFileSync(join(dir, 'ios', 'project.yml'), 'utf8')
    expect(iosYmlAgain.split('VueNativeCoreSVG:').length - 1).toBe(1)
    const iosDelegateAgain = readFileSync(join(dir, 'ios', 'Sources', 'AppDelegate.swift'), 'utf8')
    expect(iosDelegateAgain.split('VueNativeCoreSVG.register()').length - 1).toBe(1)
  })

  it('refuses to destroy local modifications in native/ without --force', () => {
    const dir = makeProject('dirty', { schema: 1, frameworkVersion: '0.20.0' })
    execFileSync('git', ['init', '-q'], { cwd: dir })
    execFileSync('git', ['add', '-A'], { cwd: dir })
    execFileSync('git', [
      '-c', 'user.email=t@example.com', '-c', 'user.name=t', 'commit', '-qm', 'base',
    ], { cwd: dir })
    writeFileSync(join(dir, 'native', 'MINE.swift'), '// my change\n')

    const refused = runUpgrade(dir, [])
    expect(refused.status).not.toBe(0)
    expect(refused.output).toContain('local modification')
    expect(existsSync(join(dir, 'native', 'MINE.swift'))).toBe(true)
  })
})
