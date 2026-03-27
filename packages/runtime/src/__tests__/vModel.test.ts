/**
 * Tests for the v-model directive.
 * v-model provides two-way data binding for native form elements.
 */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import type { ObjectDirective } from '@vue/runtime-core'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')
const { vModel: _vModel } = await import('../directives/vModel')
const { createNativeNode, resetNodeId } = await import('../node')

const vModel = _vModel as ObjectDirective

describe('vModel directive', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    resetNodeId()
  })

  describe('beforeMount', () => {
    it('sets initial value on native element', async () => {
      const el = createNativeNode('VInput')
      const vnodeWithValue = { dirs: [{ value: (_v: unknown) => { /* empty assign */ } }] } as any

      vModel.beforeMount!(el, { value: 'hello' } as any, vnodeWithValue, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops).toHaveLength(1)
      expect(ops[0].args).toEqual([el.id, 'value', 'hello'])
    })

    it('warns when assign function is missing', async () => {
      const el = createNativeNode('VInput')
      const vnodeNoAssign = { dirs: [{ value: undefined }] } as any
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})

      vModel.beforeMount!(el, { value: 'test' } as any, vnodeNoAssign, null as any)
      await nextTick()

      expect(warnSpy).toHaveBeenCalled()
      expect(warnSpy).toHaveBeenCalledWith(
        expect.stringContaining('v-model directive requires the vnode'),
      )
      warnSpy.mockRestore()
    })
  })

  describe('updated hook', () => {
    it('updates native value when parent value changes', async () => {
      const el = createNativeNode('VInput')
      const vnode = { dirs: [] } as any

      vModel.updated!(el, { value: 'newValue', oldValue: 'old' } as any, vnode, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops).toHaveLength(1)
      expect(ops[0].args).toEqual([el.id, 'value', 'newValue'])
    })

    it('skips update when value is unchanged', async () => {
      const el = createNativeNode('VInput')
      const vnode = { dirs: [] } as any

      vModel.updated!(el, { value: 'same', oldValue: 'same' } as any, vnode, null as any)
      await nextTick()

      expect(mockBridge.getOpsByType('updateProp')).toHaveLength(0)
    })

    it('applies trim modifier to parent value in updated', async () => {
      const el = createNativeNode('VInput')
      const vnode = { dirs: [] } as any

      vModel.updated!(
        el,
        { value: '  spaces  ', oldValue: 'initial', modifiers: { trim: true } } as any,
        vnode,
        null as any,
      )
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops[0].args[2]).toBe('spaces')
    })

    it('applies number modifier to parent value in updated', async () => {
      const el = createNativeNode('VInput')
      const vnode = { dirs: [] } as any

      vModel.updated!(
        el,
        { value: 789, oldValue: 0, modifiers: { number: true } } as any,
        vnode,
        null as any,
      )
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops[0].args[2]).toBe(789)
    })
  })

  describe('beforeUnmount', () => {
    it('removes event listeners', async () => {
      const el = createNativeNode('VInput')
      const vnode = { dirs: [] } as any

      vModel.beforeUnmount!(el, { value: '' } as any, vnode, null as any)
      await nextTick()

      const removeOps = mockBridge.getOpsByType('removeEventListener')
      expect(removeOps.length).toBeGreaterThanOrEqual(1)
    })
  })

  describe('edge cases', () => {
    it('works with 0 as initial value', async () => {
      const el = createNativeNode('VInput')
      const vnode = { dirs: [{ value: (_v: unknown) => { /* empty assign */ } }] } as any

      vModel.beforeMount!(el, { value: 0 } as any, vnode, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops[0].args[2]).toBe(0)
    })

    it('works with boolean false as value', async () => {
      const el = createNativeNode('VInput')
      const vnode = { dirs: [{ value: (_v: unknown) => { /* empty assign */ } }] } as any

      vModel.beforeMount!(el, { value: false } as any, vnode, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops[0].args[2]).toBe(false)
    })

    it('works with empty string as value', async () => {
      const el = createNativeNode('VInput')
      const vnode = { dirs: [{ value: (_v: unknown) => { /* empty assign */ } }] } as any

      vModel.beforeMount!(el, { value: '' } as any, vnode, null as any)
      await nextTick()

      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops[0].args[2]).toBe('')
    })
  })
})
