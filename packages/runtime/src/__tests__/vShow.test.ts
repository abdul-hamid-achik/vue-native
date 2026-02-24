/**
 * Tests for the v-show directive.
 * v-show maps to the native 'hidden' prop on views.
 */
import { describe, it, expect, beforeEach } from 'vitest'
import type { ObjectDirective } from '@vue/runtime-core'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')
const { vShow: _vShow } = await import('../directives/vShow')
const { createNativeNode, resetNodeId } = await import('../node')

// Cast to ObjectDirective to access lifecycle hooks
const vShow = _vShow as ObjectDirective

describe('vShow directive', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    resetNodeId()
  })

  describe('beforeMount', () => {
    it('sets hidden=false when value is truthy', async () => {
      const el = createNativeNode('VView')

      vShow.beforeMount!(el, { value: true } as any, null as any, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops).toHaveLength(1)
      expect(ops[0].args).toEqual([el.id, 'hidden', false])
    })

    it('sets hidden=true when value is falsy', async () => {
      const el = createNativeNode('VView')

      vShow.beforeMount!(el, { value: false } as any, null as any, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops).toHaveLength(1)
      expect(ops[0].args).toEqual([el.id, 'hidden', true])
    })

    it('sets hidden=true when value is 0', async () => {
      const el = createNativeNode('VView')

      vShow.beforeMount!(el, { value: 0 } as any, null as any, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops[0].args[2]).toBe(true)
    })

    it('sets hidden=false when value is a non-empty string', async () => {
      const el = createNativeNode('VView')

      vShow.beforeMount!(el, { value: 'visible' } as any, null as any, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops[0].args[2]).toBe(false)
    })

    it('sets hidden=true when value is null', async () => {
      const el = createNativeNode('VView')

      vShow.beforeMount!(el, { value: null } as any, null as any, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops[0].args[2]).toBe(true)
    })

    it('sets hidden=true when value is undefined', async () => {
      const el = createNativeNode('VView')

      vShow.beforeMount!(el, { value: undefined } as any, null as any, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops[0].args[2]).toBe(true)
    })
  })

  describe('updated', () => {
    it('updates hidden when value changes from true to false', async () => {
      const el = createNativeNode('VView')

      vShow.updated!(el, { value: false, oldValue: true } as any, null as any, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops).toHaveLength(1)
      expect(ops[0].args).toEqual([el.id, 'hidden', true])
    })

    it('updates hidden when value changes from false to true', async () => {
      const el = createNativeNode('VView')

      vShow.updated!(el, { value: true, oldValue: false } as any, null as any, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops).toHaveLength(1)
      expect(ops[0].args).toEqual([el.id, 'hidden', false])
    })

    it('skips update when value has not changed', async () => {
      const el = createNativeNode('VView')

      vShow.updated!(el, { value: true, oldValue: true } as any, null as any, null as any)
      await nextTick()

      expect(mockBridge.getOpsByType('updateProp')).toHaveLength(0)
    })

    it('skips update when both old and new are falsy', async () => {
      const el = createNativeNode('VView')

      vShow.updated!(el, { value: false, oldValue: false } as any, null as any, null as any)
      await nextTick()

      expect(mockBridge.getOpsByType('updateProp')).toHaveLength(0)
    })
  })
})
