import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export interface PerformanceMetrics {
  fps: number
  memoryMB: number
  bridgeOps: number
  timestamp: number
}

/**
 * Performance profiler composable.
 *
 * Starts/stops native performance profiling (FPS via CADisplayLink/Choreographer,
 * memory via task_info/Runtime, bridge operation count). While profiling is active,
 * reactive refs are updated every second via `perf:metrics` global events.
 *
 * @example
 * const { startProfiling, stopProfiling, fps, memoryMB, isProfiling } = usePerformance()
 *
 * await startProfiling()
 * // fps.value, memoryMB.value update every second
 * await stopProfiling()
 */
export function usePerformance() {
  const isProfiling = ref(false)
  const fps = ref(0)
  const memoryMB = ref(0)
  const bridgeOps = ref(0)

  let unsubscribe: (() => void) | null = null

  function handleMetrics(payload: PerformanceMetrics) {
    fps.value = payload.fps ?? 0
    memoryMB.value = payload.memoryMB ?? 0
    bridgeOps.value = payload.bridgeOps ?? 0
  }

  async function startProfiling(): Promise<void> {
    if (isProfiling.value) return

    // Subscribe to metrics events before starting
    unsubscribe = NativeBridge.onGlobalEvent('perf:metrics', handleMetrics)

    await NativeBridge.invokeNativeModule('Performance', 'startProfiling', [])
    isProfiling.value = true
  }

  async function stopProfiling(): Promise<void> {
    if (!isProfiling.value) return

    await NativeBridge.invokeNativeModule('Performance', 'stopProfiling', [])
    isProfiling.value = false

    // Unsubscribe from events
    if (unsubscribe) {
      unsubscribe()
      unsubscribe = null
    }
  }

  async function getMetrics(): Promise<PerformanceMetrics> {
    return NativeBridge.invokeNativeModule('Performance', 'getMetrics', [])
  }

  // Auto-cleanup on unmount
  onUnmounted(() => {
    if (isProfiling.value) {
      NativeBridge.invokeNativeModule('Performance', 'stopProfiling', []).catch(() => {})
      isProfiling.value = false
    }
    if (unsubscribe) {
      unsubscribe()
      unsubscribe = null
    }
  })

  return {
    startProfiling,
    stopProfiling,
    getMetrics,
    isProfiling,
    fps,
    memoryMB,
    bridgeOps,
  }
}
