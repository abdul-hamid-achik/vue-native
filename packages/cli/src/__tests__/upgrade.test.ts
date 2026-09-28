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
