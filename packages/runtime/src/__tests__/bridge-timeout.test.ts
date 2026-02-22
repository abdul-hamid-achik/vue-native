import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()
const { NativeBridge } = await import('../bridge')

describe('NativeBridge callback timeouts', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('rejects with timeout error when native does not respond', async () => {
    const promise = NativeBridge.invokeNativeModule('Test', 'slowMethod', [], 100)

    // Flush the bridge operation
    NativeBridge.flushSync()

    // Advance past the timeout
    vi.advanceTimersByTime(150)

    await expect(promise).rejects.toThrow('timed out after 100ms')
  })

  it('does not timeout if native responds in time', async () => {
    let callbackId: number | undefined

    const original = (globalThis as any).__VN_flushOperations
    ;(globalThis as any).__VN_flushOperations = (json: string) => {
      const ops = JSON.parse(json)
      const invokeOp = ops.find((o: any) => o.op === 'invokeNativeModule')
      if (invokeOp) callbackId = invokeOp.args[3]
      original(json)
    }

    const promise = NativeBridge.invokeNativeModule('Test', 'fastMethod', [], 1000)
    NativeBridge.flushSync()

    expect(callbackId).toBeDefined()
    NativeBridge.resolveCallback(callbackId!, 'success', null)

    const result = await promise
    expect(result).toBe('success')

    // Advancing time should not cause issues (timer was cleared)
    vi.advanceTimersByTime(2000)

    ;(globalThis as any).__VN_flushOperations = original
  })

  it('cleans up timers on reset', () => {
    NativeBridge.invokeNativeModule('Test', 'method', [], 100)
    NativeBridge.flushSync()

    // Reset should clear the timer
    NativeBridge.reset()

    // Advancing time should not throw (no dangling timers rejecting)
    vi.advanceTimersByTime(200)
  })
})
