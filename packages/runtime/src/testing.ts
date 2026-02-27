/**
 * @thelacanians/vue-native-runtime/testing
 *
 * Test utilities for Vue Native applications. Import from
 * '@thelacanians/vue-native-runtime/testing' to set up a mock bridge
 * for unit testing without a native runtime.
 *
 * @example
 * ```ts
 * import { installMockBridge, nextTick } from '@thelacanians/vue-native-runtime/testing'
 *
 * const { getOps, getOpsByType, reset, flush } = installMockBridge()
 *
 * // ... create app, interact with components ...
 *
 * const createOps = getOpsByType('create')
 * expect(createOps.length).toBeGreaterThan(0)
 * ```
 */

export interface CapturedOperation {
  op: string
  args: any[]
}

/**
 * Install a mock __VN_flushOperations that captures all bridge operations.
 * Returns helpers to inspect and reset captured operations.
 *
 * Call this before creating your Vue Native app in tests.
 */
export function installMockBridge() {
  const ops: CapturedOperation[] = []

  ;(globalThis as any).__VN_flushOperations = (json: string) => {
    const parsed: CapturedOperation[] = JSON.parse(json)
    ops.push(...parsed)
  }

  ;(globalThis as any).__VN_handleEvent = (..._args: any[]) => {}
  ;(globalThis as any).__VN_resolveCallback = (..._args: any[]) => {}
  ;(globalThis as any).__VN_handleGlobalEvent = (..._args: any[]) => {}
  ;(globalThis as any).__DEV__ = true

  /** Get a copy of all captured operations. */
  function getOps(): CapturedOperation[] {
    return [...ops]
  }

  /** Get captured operations filtered by operation type. */
  function getOpsByType(type: string): CapturedOperation[] {
    return ops.filter(o => o.op === type)
  }

  /** Clear all captured operations. */
  function reset() {
    ops.length = 0
  }

  /** Flush the microtask queue to ensure pending bridge operations are captured. */
  function flush() {
    return new Promise<void>(resolve => setTimeout(resolve, 0))
  }

  return { getOps, getOpsByType, reset, flush }
}

/**
 * Wait for the microtask queue and any pending bridge flushes to complete.
 * Useful after triggering state changes to ensure all bridge operations have fired.
 */
export async function nextTick() {
  await Promise.resolve()
  await Promise.resolve()
  await new Promise(resolve => setTimeout(resolve, 0))
}
