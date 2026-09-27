/**
 * Capability manifest tests.
 *
 * The manifest is the intended single source for generated docs tables and
 * editor metadata, so every value in it has to be derived from something real.
 * It used to hardcode `{ ios: 'full', android: 'full', macos: 'full' }` for all
 * forty component names, which made the macOS-only VToolbar / VSplitView /
 * VOutlineView report full support on mobile.
 */
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { BUILT_IN_COMPONENT_NAMES } from '../capabilities-manifest.js'
import { collectCapabilitiesReport } from '../commands/capabilities.js'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..', '..', '..', '..')

const REGISTRY_PATHS = {
  ios: 'native/ios/VueNativeCore/Sources/VueNativeCore/Components/ComponentRegistry.swift',
  android: 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Components/ComponentRegistry.kt',
  macos: 'native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Components/ComponentRegistry.swift',
} as const

type Platform = keyof typeof REGISTRY_PATHS

function registeredTags(platform: Platform): Set<string> {
  const path = join(repoRoot, REGISTRY_PATHS[platform])
  // Fail loudly rather than skip: this suite only ever runs inside the
  // monorepo, so a missing registry means the layout moved, not that the
  // assertion is inapplicable. A silent skip here is exactly how the original
  // hardcoded 'full' went unnoticed.
  if (!existsSync(path)) throw new Error(`ComponentRegistry not found at ${path}`)
  const tags = new Set<string>()
  for (const match of readFileSync(path, 'utf8').matchAll(/register\(\s*"([^"]+)"/g)) {
    tags.add(match[1])
  }
  return tags
}

/** Keys of the runtime's `builtInComponents` export, parsed from source. */
function runtimeComponentNames(): string[] {
  const path = join(repoRoot, 'packages/runtime/src/components/index.ts')
  if (!existsSync(path)) throw new Error(`runtime component index not found at ${path}`)

  const source = readFileSync(path, 'utf8')
  const start = source.indexOf('export const builtInComponents = {')
  expect(start, 'builtInComponents export not found').toBeGreaterThan(-1)

  const open = source.indexOf('{', start)
  let depth = 0
  let end = -1
  for (let index = open; index < source.length; index++) {
    if (source[index] === '{') depth++
    else if (source[index] === '}') {
      depth--
      if (depth === 0) {
        end = index
        break
      }
    }
  }
  expect(end).toBeGreaterThan(open)

  const body = source
    .slice(open + 1, end)
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/(^|[^:])\/\/[^\n]*/g, '$1 ')

  const names: string[] = []
  let inner = 0
  let pending = ''
  for (const char of body) {
    if ('{[('.includes(char)) inner++
    if ('}])'.includes(char)) inner--
    if (inner === 0 && char === ',') {
      const name = pending.trim().split(':')[0].trim()
      if (name) names.push(name)
      pending = ''
      continue
    }
    pending += char
  }
  const last = pending.trim().split(':')[0].trim()
  if (last) names.push(last)
  return names
}

describe('capability manifest', () => {
  const report = collectCapabilitiesReport()
  const byName = new Map(report.components.map(component => [component.name, component]))

  it('lists exactly the components the runtime exports', () => {
    // BUILT_IN_COMPONENT_NAMES is a hand-maintained list; this is the drift
    // guard that was missing when it diverged from the runtime.
    expect([...BUILT_IN_COMPONENT_NAMES].sort()).toEqual([...runtimeComponentNames()].sort())
    expect(report.components.map(component => component.name).sort())
      .toEqual([...BUILT_IN_COMPONENT_NAMES].sort())
  })

  it.each(['ios', 'android', 'macos'] as const)(
    'never reports full or stub for a component %s does not register',
    (platform) => {
      const tags = registeredTags(platform)
      for (const component of report.components) {
        const support = component.platforms[platform]
        if (support === 'full' || support === 'stub') {
          expect(
            tags.has(component.name),
            `<${component.name}> is reported '${support}' on ${platform} but is not in its ComponentRegistry`,
          ).toBe(true)
        }
      }
    },
  )

  it('reports the macOS-only desktop controls as unsupported on mobile', () => {
    for (const name of ['VToolbar', 'VSplitView', 'VOutlineView']) {
      const component = byName.get(name)
      expect(component, `${name} missing from the manifest`).toBeDefined()
      expect(component!.platforms.macos).toBe('full')
      expect(component!.platforms.ios).toBe('unsupported')
      expect(component!.platforms.android).toBe('unsupported')
    }
  })

  it('reports TypeScript-composed components as runtime-composed, not unsupported', () => {
    // These render down to other components and legitimately have no native
    // factory. Calling them unsupported would be a lie in the other direction.
    for (const name of ['VFlatList', 'VTabBar', 'VDrawer', 'VTransition', 'KeepAlive', 'VSuspense']) {
      const component = byName.get(name)
      expect(component, `${name} missing from the manifest`).toBeDefined()
      for (const platform of ['ios', 'android', 'macos'] as const) {
        expect(component!.platforms[platform], `${name} on ${platform}`).toBe('runtime-composed')
      }
    }
  })

  it('reports registered-but-inert macOS components as stub', () => {
    for (const name of ['VRefreshControl', 'VSafeArea', 'VKeyboardAvoiding', 'VStatusBar']) {
      expect(byName.get(name)!.platforms.macos, `${name} on macOS`).toBe('stub')
    }
  })

  it('emits a support value for every component on every platform', () => {
    const allowed = new Set([
      'full',
      'stub',
      'unsupported',
      'host-integration-required',
      'runtime-composed',
      'unknown',
    ])
    for (const component of report.components) {
      for (const platform of ['ios', 'android', 'macos'] as const) {
        expect(allowed.has(component.platforms[platform]), `${component.name}.${platform}`).toBe(true)
      }
    }
    // The registries ship inside the CLI package, so a resolved run must never
    // fall back to 'unknown'.
    expect(report.components.some(c => Object.values(c.platforms).includes('unknown'))).toBe(false)
  })
})
