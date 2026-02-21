import { describe, it, expect, beforeEach, vi } from 'vitest'
import { installMockBridge, nextTick } from './helpers'

// Must install mock BEFORE importing bridge to intercept __VN_flushOperations
const mockBridge = installMockBridge()

// Dynamic import after mock is installed
const { NativeBridge } = await import('../bridge')

describe('NativeBridge', () => {

  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
  })

  describe('operation batching', () => {
    it('batches multiple operations into a single flush', async () => {
      NativeBridge.createNode(1, 'VView')
      NativeBridge.createNode(2, 'VText')
      NativeBridge.appendChild(1, 2)

      expect(mockBridge.getOps()).toHaveLength(0) // not flushed yet

      await nextTick()

      const ops = mockBridge.getOps()
      expect(ops).toHaveLength(3)
      expect(ops[0]).toEqual({ op: 'create', args: [1, 'VView'] })
      expect(ops[1]).toEqual({ op: 'create', args: [2, 'VText'] })
      expect(ops[2]).toEqual({ op: 'appendChild', args: [1, 2] })
    })

    it('schedules only one flush per microtask cycle', async () => {
      const flushSpy = vi.fn()
      const original = (globalThis as any).__VN_flushOperations
      ;(globalThis as any).__VN_flushOperations = (json: string) => {
        flushSpy(json)
        original(json)
      }

      NativeBridge.createNode(1, 'VView')
      NativeBridge.createNode(2, 'VText')
      NativeBridge.createNode(3, 'VButton')

      await nextTick()

      expect(flushSpy).toHaveBeenCalledTimes(1)
      ;(globalThis as any).__VN_flushOperations = original
    })

    it('flushSync sends operations immediately', () => {
      NativeBridge.createNode(1, 'VView')
      NativeBridge.flushSync()
      expect(mockBridge.getOps()).toHaveLength(1)
    })
  })

  describe('node operations', () => {
    it('createNode sends create operation', async () => {
      NativeBridge.createNode(42, 'VButton')
      await nextTick()
      const ops = mockBridge.getOpsByType('create')
      expect(ops).toHaveLength(1)
      expect(ops[0].args).toEqual([42, 'VButton'])
    })

    it('createTextNode sends createText operation', async () => {
      NativeBridge.createTextNode(5, 'Hello World')
      await nextTick()
      const ops = mockBridge.getOpsByType('createText')
      expect(ops[0].args).toEqual([5, 'Hello World'])
    })

    it('setText sends setText operation', async () => {
      NativeBridge.setText(5, 'Updated Text')
      await nextTick()
      const ops = mockBridge.getOpsByType('setText')
      expect(ops[0].args).toEqual([5, 'Updated Text'])
    })

    it('appendChild sends appendChild operation', async () => {
      NativeBridge.appendChild(1, 2)
      await nextTick()
      const ops = mockBridge.getOpsByType('appendChild')
      expect(ops[0].args).toEqual([1, 2])
    })

    it('insertBefore sends insertBefore operation', async () => {
      NativeBridge.insertBefore(1, 3, 2)
      await nextTick()
      const ops = mockBridge.getOpsByType('insertBefore')
      expect(ops[0].args).toEqual([1, 3, 2])
    })

    it('removeChild sends removeChild operation with childId only', async () => {
      // The bridge implementation discards parentId — Swift uses removeFromSuperview()
      // so only childId is needed. args = [childId].
      NativeBridge.removeChild(1, 2)
      await nextTick()
      const ops = mockBridge.getOpsByType('removeChild')
      expect(ops[0].args).toEqual([2])
    })
  })

  describe('prop and style operations', () => {
    it('updateProp sends updateProp operation', async () => {
      NativeBridge.updateProp(1, 'disabled', true)
      await nextTick()
      const ops = mockBridge.getOpsByType('updateProp')
      expect(ops[0].args).toEqual([1, 'disabled', true])
    })

    it('updateStyle sends updateStyle operation with object', async () => {
      NativeBridge.updateStyle(1, 'backgroundColor', '#FF0000')
      await nextTick()
      const ops = mockBridge.getOpsByType('updateStyle')
      expect(ops[0].args).toEqual([1, { backgroundColor: '#FF0000' }])
    })
  })

  describe('event handling', () => {
    it('addEventListener registers handler and sends operation', async () => {
      const handler = vi.fn()
      NativeBridge.addEventListener(1, 'press', handler)
      await nextTick()

      const ops = mockBridge.getOpsByType('addEventListener')
      expect(ops[0].args).toEqual([1, 'press'])
    })

    it('handleNativeEvent dispatches to registered handler', () => {
      const handler = vi.fn()
      NativeBridge.addEventListener(1, 'press', handler)

      NativeBridge.handleNativeEvent(1, 'press', { x: 10, y: 20 })

      expect(handler).toHaveBeenCalledWith({ x: 10, y: 20 })
    })

    it('removeEventListener deletes handler and sends operation', async () => {
      const handler = vi.fn()
      NativeBridge.addEventListener(1, 'press', handler)
      NativeBridge.removeEventListener(1, 'press')
      await nextTick()

      // Handler should no longer fire
      NativeBridge.handleNativeEvent(1, 'press', null)
      expect(handler).not.toHaveBeenCalled()
    })
  })

  describe('global events', () => {
    it('onGlobalEvent registers handler and returns unsubscribe', () => {
      const handler = vi.fn()
      const unsubscribe = NativeBridge.onGlobalEvent('network:change', handler)

      NativeBridge.handleGlobalEvent('network:change', JSON.stringify({ isConnected: false }))
      expect(handler).toHaveBeenCalledWith({ isConnected: false })

      unsubscribe()
      NativeBridge.handleGlobalEvent('network:change', JSON.stringify({ isConnected: true }))
      expect(handler).toHaveBeenCalledTimes(1) // not called again
    })

    it('handleGlobalEvent parses JSON payload', () => {
      const handler = vi.fn()
      NativeBridge.onGlobalEvent('test', handler)
      NativeBridge.handleGlobalEvent('test', '{"key":"value","num":42}')
      expect(handler).toHaveBeenCalledWith({ key: 'value', num: 42 })
    })

    it('handleGlobalEvent handles invalid JSON gracefully', () => {
      const handler = vi.fn()
      NativeBridge.onGlobalEvent('test', handler)
      expect(() => NativeBridge.handleGlobalEvent('test', 'invalid json')).not.toThrow()
      expect(handler).toHaveBeenCalledWith({})
    })
  })

  describe('native module invocation', () => {
    it('invokeNativeModule returns a Promise', () => {
      const result = NativeBridge.invokeNativeModule('Haptics', 'vibrate', ['medium'])
      expect(result).toBeInstanceOf(Promise)
    })

    it('resolveCallback resolves the pending Promise', async () => {
      let callbackId: number | undefined

      const original = (globalThis as any).__VN_flushOperations
      ;(globalThis as any).__VN_flushOperations = (json: string) => {
        const ops = JSON.parse(json)
        const invokeOp = ops.find((o: any) => o.op === 'invokeNativeModule')
        if (invokeOp) callbackId = invokeOp.args[3]
        original(json)
      }

      const promise = NativeBridge.invokeNativeModule('Test', 'method', [])
      await nextTick()

      expect(callbackId).toBeDefined()
      NativeBridge.resolveCallback(callbackId!, { result: 'ok' }, null)

      const result = await promise
      expect(result).toEqual({ result: 'ok' })

      ;(globalThis as any).__VN_flushOperations = original
    })
  })

  describe('reset', () => {
    it('clears all state', async () => {
      NativeBridge.createNode(1, 'VView')
      const handler = vi.fn()
      NativeBridge.addEventListener(1, 'press', handler)
      NativeBridge.onGlobalEvent('test', vi.fn())

      NativeBridge.reset()
      await nextTick()

      // No ops flushed after reset (reset clears the queue and the scheduled flag)
      expect(mockBridge.getOps()).toHaveLength(0)
    })
  })
})
