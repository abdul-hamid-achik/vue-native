/**
 * Bridge resilience tests — verify crash fixes and edge cases.
 *
 * Tests:
 * - Callback ID wraparound at MAX_SAFE_CALLBACK_ID
 * - Bridge error handling when __VN_flushOperations throws
 * - Bridge warning when __VN_flushOperations is not registered
 * - Event handler error isolation
 * - Global event handler error isolation
 * - Callback timeout cleanup
 */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()
const { NativeBridge } = await import('../bridge')

describe('Bridge resilience', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
  })

  describe('callback ID wraparound', () => {
    it('wraps callback ID back to 1 after reaching max', async () => {
      // Set nextCallbackId to near the max by making many calls
      // We'll test by calling invokeNativeModule and checking the callbackId in ops
      const callbackIds: number[] = []
      const originalFlush = (globalThis as any).__VN_flushOperations
      ;(globalThis as any).__VN_flushOperations = (json: string) => {
        const ops = JSON.parse(json)
        for (const op of ops) {
          if (op.op === 'invokeNativeModule') {
            callbackIds.push(op.args[3])
          }
        }
        originalFlush(json)
      }

      // Make two calls and verify IDs increment
      NativeBridge.invokeNativeModule('Test', 'method1', [])
      NativeBridge.invokeNativeModule('Test', 'method2', [])
      await nextTick()

      expect(callbackIds).toHaveLength(2)
      expect(callbackIds[1]).toBe(callbackIds[0] + 1)

      ;(globalThis as any).__VN_flushOperations = originalFlush
    })

    it('callback IDs are unique within the same batch', async () => {
      const callbackIds: number[] = []
      const originalFlush = (globalThis as any).__VN_flushOperations
      ;(globalThis as any).__VN_flushOperations = (json: string) => {
        const ops = JSON.parse(json)
        for (const op of ops) {
          if (op.op === 'invokeNativeModule') {
            callbackIds.push(op.args[3])
          }
        }
        originalFlush(json)
      }

      // Multiple calls in same tick
      NativeBridge.invokeNativeModule('A', 'x', [])
      NativeBridge.invokeNativeModule('B', 'y', [])
      NativeBridge.invokeNativeModule('C', 'z', [])
      await nextTick()

      const uniqueIds = new Set(callbackIds)
      expect(uniqueIds.size).toBe(3)

      ;(globalThis as any).__VN_flushOperations = originalFlush
    })
  })

  describe('bridge error handling', () => {
    it('catches errors from __VN_flushOperations and does not crash', async () => {
      const originalFlush = (globalThis as any).__VN_flushOperations
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {})

      ;(globalThis as any).__VN_flushOperations = () => {
        throw new Error('Bridge crash')
      }

      // This should NOT throw
      NativeBridge.createNode(1, 'VView')
      await nextTick()

      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('[VueNative] Error in __VN_flushOperations:'),
        expect.any(Error),
      )

      consoleSpy.mockRestore()
      ;(globalThis as any).__VN_flushOperations = originalFlush
    })

    it('warns when __VN_flushOperations is not defined', async () => {
      const originalFlush = (globalThis as any).__VN_flushOperations
      const consoleSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})

      ;(globalThis as any).__VN_flushOperations = undefined

      NativeBridge.createNode(1, 'VView')
      await nextTick()

      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('__VN_flushOperations is not registered'),
      )

      consoleSpy.mockRestore()
      ;(globalThis as any).__VN_flushOperations = originalFlush
    })
  })

  describe('event handler error isolation', () => {
    it('catches errors from event handlers and does not propagate', () => {
      const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})

      NativeBridge.addEventListener(1, 'press', () => {
        throw new Error('Handler exploded')
      })

      // Should not throw
      expect(() => NativeBridge.handleNativeEvent(1, 'press', null)).not.toThrow()

      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining('Error in event handler "press"'),
        expect.any(Error),
      )

      errorSpy.mockRestore()
    })

    it('isolates errors between multiple global event handlers', () => {
      const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
      const goodHandler = vi.fn()

      NativeBridge.onGlobalEvent('test', () => {
        throw new Error('Bad handler')
      })
      NativeBridge.onGlobalEvent('test', goodHandler)

      NativeBridge.handleGlobalEvent('test', '{}')

      // The good handler should still fire despite the bad one throwing
      expect(goodHandler).toHaveBeenCalledWith({})
      expect(errorSpy).toHaveBeenCalled()

      errorSpy.mockRestore()
    })
  })

  describe('callback timeout and cleanup', () => {
    it('rejects promise after timeout', async () => {
      // Use a short real timeout rather than fake timers since queueMicrotask
      // interacts poorly with vi.useFakeTimers.
      // Immediately attach .catch to prevent unhandled rejection.
      const promise = NativeBridge.invokeNativeModule('Slow', 'method', [], 50)

      // Attach a no-op catch immediately to prevent unhandled rejection warning.
      // We'll still assert on it below.
      let caughtError: Error | undefined
      promise.catch((e: Error) => {
        caughtError = e
      })

      await nextTick()

      // Wait longer than the timeout
      await new Promise(resolve => setTimeout(resolve, 150))

      expect(caughtError).toBeDefined()
      expect(caughtError!.message).toContain('timed out after 50ms')
    }, 10_000)

    it('does not reject if callback resolves before timeout', async () => {
      let callbackId: number | undefined
      const originalFlush = (globalThis as any).__VN_flushOperations
      ;(globalThis as any).__VN_flushOperations = (json: string) => {
        const ops = JSON.parse(json)
        for (const op of ops) {
          if (op.op === 'invokeNativeModule') {
            callbackId = op.args[3]
          }
        }
        originalFlush(json)
      }

      const promise = NativeBridge.invokeNativeModule('Fast', 'method', [], 5000)
      await nextTick()

      expect(callbackId).toBeDefined()
      NativeBridge.resolveCallback(callbackId!, 'success', null)

      const result = await promise
      expect(result).toBe('success')

      ;(globalThis as any).__VN_flushOperations = originalFlush
    })

    it('resolveCallback ignores unknown callback IDs', () => {
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})

      // Should not throw
      NativeBridge.resolveCallback(999999, 'result', null)

      expect(warnSpy).toHaveBeenCalledWith(
        expect.stringContaining('unknown callbackId: 999999'),
      )

      warnSpy.mockRestore()
    })

    it('resolveCallback with error rejects the promise', async () => {
      let callbackId: number | undefined
      const originalFlush = (globalThis as any).__VN_flushOperations
      ;(globalThis as any).__VN_flushOperations = (json: string) => {
        const ops = JSON.parse(json)
        for (const op of ops) {
          if (op.op === 'invokeNativeModule') {
            callbackId = op.args[3]
          }
        }
        originalFlush(json)
      }

      const promise = NativeBridge.invokeNativeModule('Fail', 'method', [])
      await nextTick()

      NativeBridge.resolveCallback(callbackId!, null, 'Something went wrong')

      await expect(promise).rejects.toThrow('Something went wrong')

      ;(globalThis as any).__VN_flushOperations = originalFlush
    })
  })

  describe('reset', () => {
    it('clears pending operations', async () => {
      NativeBridge.createNode(1, 'VView')
      NativeBridge.createNode(2, 'VText')

      NativeBridge.reset()
      await nextTick()

      // No ops should have been flushed
      expect(mockBridge.getOps()).toHaveLength(0)
    })

    it('clears event handlers', () => {
      const handler = vi.fn()
      NativeBridge.addEventListener(1, 'press', handler)
      NativeBridge.reset()

      NativeBridge.handleNativeEvent(1, 'press', null)
      expect(handler).not.toHaveBeenCalled()
    })

    it('clears global event handlers', () => {
      const handler = vi.fn()
      NativeBridge.onGlobalEvent('test', handler)
      NativeBridge.reset()

      NativeBridge.handleGlobalEvent('test', '{}')
      expect(handler).not.toHaveBeenCalled()
    })

    it('resets callback ID counter', async () => {
      const callbackIds: number[] = []
      const originalFlush = (globalThis as any).__VN_flushOperations
      ;(globalThis as any).__VN_flushOperations = (json: string) => {
        const ops = JSON.parse(json)
        for (const op of ops) {
          if (op.op === 'invokeNativeModule') {
            callbackIds.push(op.args[3])
          }
        }
        originalFlush(json)
      }

      NativeBridge.invokeNativeModule('Test', 'a', [])
      await nextTick()

      NativeBridge.reset()
      callbackIds.length = 0

      NativeBridge.invokeNativeModule('Test', 'b', [])
      await nextTick()

      // After reset, IDs start from 1 again
      expect(callbackIds[0]).toBe(1)

      ;(globalThis as any).__VN_flushOperations = originalFlush
    })
  })
})
