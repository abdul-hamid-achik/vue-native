/**
 * Test helpers for navigation tests.
 * Sets up a mock native bridge so tests run without a Swift runtime.
 */

import { vi } from 'vitest'

export interface CapturedOperation {
  op: string
  args: any[]
}

export function installMockBridge() {
  const ops: CapturedOperation[] = []

  ;(globalThis as any).__VN_flushOperations = (json: string) => {
    const parsed: CapturedOperation[] = JSON.parse(json)
    ops.push(...parsed)
  }

  ;(globalThis as any).__VN_handleEvent = vi.fn()
  ;(globalThis as any).__VN_resolveCallback = vi.fn()
  ;(globalThis as any).__VN_handleGlobalEvent = vi.fn()
  ;(globalThis as any).__DEV__ = true

  function getOps(): CapturedOperation[] {
    return [...ops]
  }

  function getOpsByType(type: string): CapturedOperation[] {
    return ops.filter(o => o.op === type)
  }

  function reset() {
    ops.length = 0
  }

  return { getOps, getOpsByType, reset }
}

export async function nextTick() {
  await Promise.resolve()
  await Promise.resolve()
  await new Promise(resolve => setTimeout(resolve, 0))
}
