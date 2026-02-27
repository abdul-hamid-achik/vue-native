/**
 * Performance profiler composable tests.
 * Verifies start/stop/metrics behavior and reactive state updates.
 */
import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { installMockBridge, withSetup } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')

let invokeModuleSpy: ReturnType<typeof vi.spyOn>
let onGlobalEventSpy: ReturnType<typeof vi.spyOn>

const globalEventHandlers: Map<string, Array<(payload: any) => void>> = new Map()

describe('usePerformance', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    globalEventHandlers.clear()

    invokeModuleSpy = vi.spyOn(NativeBridge, 'invokeNativeModule').mockImplementation(
      () => Promise.resolve(undefined as any),
    )

    onGlobalEventSpy = vi.spyOn(NativeBridge, 'onGlobalEvent').mockImplementation(
      (event: string, handler: (payload: any) => void) => {
        if (!globalEventHandlers.has(event)) {
          globalEventHandlers.set(event, [])
        }
        globalEventHandlers.get(event)!.push(handler)
        return () => {
          const handlers = globalEventHandlers.get(event)
          if (handlers) {
            const idx = handlers.indexOf(handler)
            if (idx > -1) handlers.splice(idx, 1)
          }
        }
      },
    )
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  function triggerGlobalEvent(event: string, payload: any) {
    const handlers = globalEventHandlers.get(event) ?? []
    for (const handler of handlers) {
      handler(payload)
    }
  }

  it('startProfiling calls Performance.startProfiling', async () => {
    const { usePerformance } = await import('../composables/usePerformance')
    const { startProfiling } = await withSetup(() => usePerformance())
    await startProfiling()
    expect(invokeModuleSpy).toHaveBeenCalledWith('Performance', 'startProfiling', [])
  })

  it('stopProfiling calls Performance.stopProfiling', async () => {
    const { usePerformance } = await import('../composables/usePerformance')
    const { startProfiling, stopProfiling } = await withSetup(() => usePerformance())
    await startProfiling()
    await stopProfiling()
    expect(invokeModuleSpy).toHaveBeenCalledWith('Performance', 'stopProfiling', [])
  })

  it('isProfiling ref tracks profiling state', async () => {
    const { usePerformance } = await import('../composables/usePerformance')
    const { startProfiling, stopProfiling, isProfiling } = await withSetup(() => usePerformance())

    expect(isProfiling.value).toBe(false)
    await startProfiling()
    expect(isProfiling.value).toBe(true)
    await stopProfiling()
    expect(isProfiling.value).toBe(false)
  })

  it('subscribes to perf:metrics event on start', async () => {
    const { usePerformance } = await import('../composables/usePerformance')
    const { startProfiling } = await withSetup(() => usePerformance())
    await startProfiling()

    expect(onGlobalEventSpy).toHaveBeenCalledWith('perf:metrics', expect.any(Function))
  })

  it('unsubscribes from perf:metrics event on stop', async () => {
    const { usePerformance } = await import('../composables/usePerformance')
    const { startProfiling, stopProfiling } = await withSetup(() => usePerformance())

    await startProfiling()
    const handlersBeforeStop = globalEventHandlers.get('perf:metrics')?.length ?? 0
    expect(handlersBeforeStop).toBe(1)

    await stopProfiling()
    const handlersAfterStop = globalEventHandlers.get('perf:metrics')?.length ?? 0
    expect(handlersAfterStop).toBe(0)
  })

  it('updates reactive refs when perf:metrics event fires', async () => {
    const { usePerformance } = await import('../composables/usePerformance')
    const { startProfiling, fps, memoryMB, bridgeOps } = await withSetup(() => usePerformance())

    await startProfiling()

    expect(fps.value).toBe(0)
    expect(memoryMB.value).toBe(0)
    expect(bridgeOps.value).toBe(0)

    triggerGlobalEvent('perf:metrics', {
      fps: 59.8,
      memoryMB: 128.5,
      bridgeOps: 42,
      timestamp: Date.now(),
    })

    expect(fps.value).toBe(59.8)
    expect(memoryMB.value).toBe(128.5)
    expect(bridgeOps.value).toBe(42)
  })

  it('getMetrics calls Performance.getMetrics', async () => {
    const metrics = { fps: 60, memoryMB: 100, bridgeOps: 10, timestamp: Date.now() }
    invokeModuleSpy.mockResolvedValueOnce(metrics)

    const { usePerformance } = await import('../composables/usePerformance')
    const { getMetrics } = await withSetup(() => usePerformance())
    const result = await getMetrics()
    expect(invokeModuleSpy).toHaveBeenCalledWith('Performance', 'getMetrics', [])
    expect(result).toEqual(metrics)
  })

  it('does not start profiling twice', async () => {
    const { usePerformance } = await import('../composables/usePerformance')
    const { startProfiling, isProfiling: _isProfiling } = await withSetup(() => usePerformance())

    await startProfiling()
    await startProfiling()

    // Only one call to startProfiling should be made
    const startCalls = invokeModuleSpy.mock.calls.filter(
      (c: unknown[]) => c[0] === 'Performance' && c[1] === 'startProfiling',
    )
    expect(startCalls).toHaveLength(1)
  })

  it('does not stop profiling when not started', async () => {
    const { usePerformance } = await import('../composables/usePerformance')
    const { stopProfiling } = await withSetup(() => usePerformance())

    await stopProfiling()

    const stopCalls = invokeModuleSpy.mock.calls.filter(
      (c: unknown[]) => c[0] === 'Performance' && c[1] === 'stopProfiling',
    )
    expect(stopCalls).toHaveLength(0)
  })
})
