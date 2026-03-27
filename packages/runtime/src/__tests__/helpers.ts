/**
 * Test helpers for Vue Native unit tests.
 * Sets up a mock native bridge so tests run without a Swift runtime.
 */

import { vi } from 'vitest'

export interface CapturedOperation {
  op: string
  // Native bridge payloads are intentionally heterogeneous in tests.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  args: any[]
}

interface MockBridgeGlobals {
  __VN_flushOperations?: (json: string) => void
  __VN_handleEvent?: (...args: unknown[]) => void
  __VN_resolveCallback?: (...args: unknown[]) => void
  __VN_handleGlobalEvent?: (...args: unknown[]) => void
  __DEV__?: boolean
}

/**
 * Install a mock __VN_flushOperations that captures all bridge operations.
 * Returns a function to retrieve captured ops and one to reset them.
 */
export function installMockBridge() {
  const ops: CapturedOperation[] = []
  const mockGlobals = globalThis as typeof globalThis & MockBridgeGlobals

  mockGlobals.__VN_flushOperations = (json: string) => {
    const parsed: CapturedOperation[] = JSON.parse(json)
    ops.push(...parsed)
  }

  mockGlobals.__VN_handleEvent = vi.fn()
  mockGlobals.__VN_resolveCallback = vi.fn()
  mockGlobals.__VN_handleGlobalEvent = vi.fn()
  mockGlobals.__DEV__ = true

  function getOps(): CapturedOperation[] {
    return [...ops]
  }

  function getOpsByType(type: string): CapturedOperation[] {
    return ops.filter(o => o.op === type)
  }

  function reset() {
    ops.length = 0
  }

  function flush(): Promise<void> {
    // Force any pending microtask flushes in the bridge
    return new Promise<void>(resolve => setTimeout(resolve, 0))
  }

  return { getOps, getOpsByType, reset, flush }
}

/**
 * Wait for the microtask queue and any pending bridge flushes.
 */
export async function nextTick() {
  await Promise.resolve()
  await Promise.resolve()
  await new Promise(resolve => setTimeout(resolve, 0))
}

/**
 * Run a composable inside a proper Vue component setup context.
 * This silences "onUnmounted is called when there is no active component
 * instance" warnings and makes test execution more realistic.
 */
export async function withSetup<T>(composable: () => T): Promise<T> {
  const { baseCreateApp } = await import('../renderer')
  const { createNativeNode } = await import('../node')

  let result!: T
  const app = baseCreateApp({
    setup() {
      result = composable()
      return () => {}
    },
  })
  app.mount(createNativeNode('__ROOT__'))
  return result
}
