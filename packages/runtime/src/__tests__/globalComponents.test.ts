/**
 * GlobalComponents augmentation tests — ensures language tooling (Volar,
 * vue-tsc, editor LSP) can resolve every globally registered Vue Native
 * component in templates.
 */
import { describe, it, expect, expectTypeOf } from 'vitest'
import type { GlobalComponents } from '@vue/runtime-core'
import '../globalComponents'
import { builtInComponents } from '../components'

// Compile-time assertion: every globally registered component name must be
// declared in the GlobalComponents augmentation. If a component is added to
// builtInComponents or createApp() without updating globalComponents.ts,
// `tsc --noEmit` fails here.
type RegisteredNames = keyof typeof builtInComponents
// Registered by createApp() in addition to the built-in registry.
// (KeepAlive comes from @vue/runtime-core's own GlobalComponents.)
type ExtraRegistrations = 'ErrorBoundary' | 'VErrorBoundary'
type AllGlobalNames = RegisteredNames | ExtraRegistrations

describe('GlobalComponents augmentation', () => {
  it('declares every globally registered component for language tooling', () => {
    expectTypeOf<AllGlobalNames>().toMatchTypeOf<keyof GlobalComponents>()
  })

  it('only registers plain tag names in builtInComponents', () => {
    // Dotted registrations (e.g. "VDrawer.Item") cannot be declared in
    // GlobalComponents, so they must stay out of the built-in registry.
    const names = Object.keys(builtInComponents)
    expect(names.length).toBeGreaterThan(0)
    for (const name of names) {
      expect(name).toMatch(/^[A-Z][A-Za-z0-9]*$/)
    }
  })
})
