/**
 * Bridge serialization and callback-capacity tests.
 *
 * These cover three failure modes that were previously unguarded:
 * - A single unserializable argument used to discard the entire op batch after
 *   pendingOps had already been detached, desyncing JS from native silently.
 * - The callback cap evicted oldest-insertion-first, which killed exactly the
 *   `timeoutMs: 0` long-running calls the opt-out exists to protect.
 * - reset() discarded in-flight callbacks without settling them, stranding any
 *   awaiting closure forever.
 */
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { installMockBridge, nextTick } from './helpers'

const mockBridge = installMockBridge()
const { NativeBridge } = await import('../bridge')

/** Matches NativeBridgeImpl.MAX_PENDING_CALLBACKS. */
const MAX_PENDING_CALLBACKS = 1000

describe('Bridge serialization and callback capacity', () => {
  let consoleSpy: ReturnType<typeof vi.spyOn>

  beforeEach(() => {
    consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
    mockBridge.reset()
    NativeBridge.reset()
  })

  afterEach(() => {
    consoleSpy.mockRestore()
    NativeBridge.reset()
  })

  describe('unserializable operation arguments', () => {
    it('drops only the offending operation and still flushes its siblings', async () => {
      const bridgeErrors: Array<{ message: string }> = []
      const unsubscribe = NativeBridge.onGlobalEvent<{ message: string }>(
        'bridge:error',
        payload => bridgeErrors.push(payload),
      )

      NativeBridge.createNode(1, 'VView')
      // BigInt has no JSON representation and makes the whole-batch
      // JSON.stringify throw.
      NativeBridge.updateProp(1, 'big', BigInt(9007199254740993n))
      NativeBridge.createNode(2, 'VText')
      await nextTick()

      const ops = mockBridge.getOps()
      const creates = ops.filter(o => o.op === 'create').map(o => o.args[0])

      // Both siblings survived; before the fix the entire batch was lost.
      expect(creates).toEqual([1, 2])
      expect(ops.some(o => o.op === 'updateProp')).toBe(false)

      // And the drop is reported rather than silent.
      expect(bridgeErrors.length).toBeGreaterThan(0)
      expect(bridgeErrors.some(e => e.message.includes('Dropped unserializable')))
        .toBe(true)
      expect(bridgeErrors.some(e => e.message.includes('updateProp'))).toBe(true)
      expect(bridgeErrors.some(e => e.message.includes('BigInt'))).toBe(true)

      unsubscribe()
    })

    it('reports how many operations were dropped out of the batch', async () => {
      const bridgeErrors: Array<{ message: string }> = []
      const unsubscribe = NativeBridge.onGlobalEvent<{ message: string }>(
        'bridge:error',
        payload => bridgeErrors.push(payload),
      )

      // A circular reference makes JSON.stringify throw. Note that a Symbol does
      // not — it serializes to null — so it is not a valid stand-in here.
      const circular: Record<string, unknown> = {}
      circular.self = circular

      NativeBridge.createNode(1, 'VView')
      NativeBridge.updateProp(1, 'circular', circular)
      await nextTick()

      const summary = bridgeErrors.find(e => e.message.includes('could not be serialized'))
      expect(summary).toBeDefined()
      expect(summary?.message).toContain('1 of 2')

      unsubscribe()
    })
  })

  describe('callback capacity', () => {
    it('never evicts a timeout-disabled callback when the queue is full', async () => {
      const untimed: Array<Promise<unknown>> = []
      for (let i = 0; i < MAX_PENDING_CALLBACKS; i++) {
        untimed.push(NativeBridge.invokeNativeModule('Long', 'running', [], 0))
      }

      let untimedRejections = 0
      untimed.forEach(p => p.catch(() => {
        untimedRejections++
      }))

      // A new timed call must be refused rather than killing an in-flight
      // download/purchase that opted out of the timeout.
      await expect(
        NativeBridge.invokeNativeModule('Short', 'call', [], 60_000),
      ).rejects.toThrow(/refusing to start/)

      expect(untimedRejections).toBe(0)
    })

    it('still evicts the oldest timed callback when the queue is full', async () => {
      const timed: Array<Promise<unknown>> = []
      for (let i = 0; i < MAX_PENDING_CALLBACKS; i++) {
        timed.push(NativeBridge.invokeNativeModule('Mod', 'method', [], 60_000))
      }

      const evictions: Array<unknown> = []
      timed[0].catch(err => evictions.push(err))
      // Keep the rest handled so they cannot surface as unhandled rejections.
      timed.slice(1).forEach(p => p.catch(() => {}))

      // Not awaited: the native side never answers, so this promise only settles
      // when reset() runs. Eviction of timed[0] happens synchronously inside it.
      const newcomer = NativeBridge.invokeNativeModule('Mod', 'method', [], 60_000)
      newcomer.catch(() => {})
      await nextTick()

      expect(evictions).toHaveLength(1)
      expect(String(evictions[0])).toContain('evicting oldest timed pending callback')
    })
  })

  describe('reset', () => {
    it('rejects in-flight callbacks instead of stranding them', async () => {
      const pending = NativeBridge.invokeNativeModule('Mod', 'method', [], 0)
      const assertion = expect(pending).rejects.toThrow(/bridge was reset/)

      NativeBridge.reset()

      await assertion
    })
  })
})
