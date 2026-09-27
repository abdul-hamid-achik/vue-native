/**
 * Config-drift warnings for the native host projects.
 *
 * `vue-native.config.ts` values are only used at scaffold time; after `create`
 * the native project files are authoritative. These checks warn when the two
 * have since diverged, because a config value that silently does nothing is
 * worse than no config value. The macOS host is new, and its check previously
 * did not exist at all.
 */
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { findIOSConfigDrift, findMacOSConfigDrift } from '../native-project.js'

let dir: string

beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), 'vn-drift-'))
})

afterEach(() => {
  rmSync(dir, { recursive: true, force: true })
})

function writeProjectYml(platform: 'iOS' | 'macOS', version: string): string {
  mkdirSync(dir, { recursive: true })
  const path = join(dir, 'project.yml')
  writeFileSync(path, `name: probe
options:
  bundleIdPrefix: com.vuenative
  deploymentTarget:
    ${platform}: "${version}"
`)
  return path
}

describe('findIOSConfigDrift', () => {
  it('is silent when config and project.yml agree', () => {
    writeProjectYml('iOS', '16.0')
    expect(findIOSConfigDrift(dir, { deploymentTarget: '16.0' })).toEqual([])
  })

  it('warns when they disagree', () => {
    writeProjectYml('iOS', '17.2')
    const warnings = findIOSConfigDrift(dir, { deploymentTarget: '16.0' })
    expect(warnings).toHaveLength(1)
    expect(warnings[0]).toContain('ios.deploymentTarget=16.0')
    expect(warnings[0]).toContain('uses 17.2')
  })

  it('is silent when there is no project.yml to compare against', () => {
    expect(findIOSConfigDrift(dir, { deploymentTarget: '16.0' })).toEqual([])
  })
})

describe('findMacOSConfigDrift', () => {
  it('is silent when config and project.yml agree', () => {
    writeProjectYml('macOS', '15.0')
    expect(findMacOSConfigDrift(dir, { deploymentTarget: '15.0' })).toEqual([])
  })

  it('warns when they disagree', () => {
    writeProjectYml('macOS', '15.2')
    const warnings = findMacOSConfigDrift(dir, { deploymentTarget: '15.0' })
    expect(warnings).toHaveLength(1)
    expect(warnings[0]).toContain('macos.deploymentTarget=15.0')
    expect(warnings[0]).toContain('uses 15.2')
  })

  it('does not confuse the iOS key for the macOS one', () => {
    // A project.yml that only carries an iOS entry must not satisfy the macOS
    // check, and vice versa: the two keys are siblings under deploymentTarget.
    writeProjectYml('iOS', '15.2')
    expect(findMacOSConfigDrift(dir, { deploymentTarget: '15.0' })).toEqual([])
  })

  it('is silent when there is no project.yml to compare against', () => {
    expect(findMacOSConfigDrift(dir, { deploymentTarget: '15.0' })).toEqual([])
  })
})
