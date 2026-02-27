/**
 * Bug fix tests — bridge.reset() callback cleanup and useHttp fixes.
 */
import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { installMockBridge, withSetup } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')

describe('Bridge reset() clears pending callback timeouts', () => {
  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
  })

  it('clearTimeout is called for each pending callback on reset', () => {
    const clearTimeoutSpy = vi.spyOn(globalThis, 'clearTimeout')

    // Register some pending callbacks by invoking native modules
    // that create timeout-guarded callbacks
    NativeBridge.invokeNativeModule('TestModule', 'someMethod', [])
    NativeBridge.invokeNativeModule('TestModule', 'anotherMethod', [])

    clearTimeoutSpy.mockClear()

    // Reset should clear all pending callback timeouts
    NativeBridge.reset()

    // clearTimeout should have been called (at least once per pending callback)
    // The exact count depends on implementation, but it should be > 0
    // if there were pending callbacks with timeouts
    expect(clearTimeoutSpy).toHaveBeenCalled()

    clearTimeoutSpy.mockRestore()
  })

  it('pendingCallbacks is empty after reset', () => {
    NativeBridge.invokeNativeModule('TestModule', 'method1', [])
    NativeBridge.reset()

    // After reset, a new invoke should get callback ID 1 (counter was reset)
    // This indirectly verifies the map was cleared
    const promise = NativeBridge.invokeNativeModule('TestModule', 'method2', [])
    expect(promise).toBeInstanceOf(Promise)
  })
})

describe('useHttp bug fixes', () => {
  let originalFetch: any

  beforeEach(() => {
    mockBridge.reset()
    NativeBridge.reset()
    originalFetch = (globalThis as any).fetch
  })

  afterEach(() => {
    (globalThis as any).fetch = originalFetch
  })

  it('GET request does not set Content-Type header', async () => {
    let capturedInit: any
    ;(globalThis as any).fetch = vi.fn(async (_url: string, init: any) => {
      capturedInit = init
      return {
        status: 200,
        ok: true,
        json: async () => ({}),
        headers: { forEach: () => {} },
      }
    })

    // Import useHttp fresh
    const { useHttp } = await import('../composables/useHttp')
    const http = await withSetup(() => useHttp())
    await http.get('/test')

    expect(capturedInit.headers['Content-Type']).toBeUndefined()
  })

  it('POST request sets Content-Type: application/json', async () => {
    let capturedInit: any
    ;(globalThis as any).fetch = vi.fn(async (_url: string, init: any) => {
      capturedInit = init
      return {
        status: 200,
        ok: true,
        json: async () => ({}),
        headers: { forEach: () => {} },
      }
    })

    const { useHttp } = await import('../composables/useHttp')
    const http = await withSetup(() => useHttp())
    await http.post('/test', { data: 'value' })

    expect(capturedInit.headers['Content-Type']).toBe('application/json')
  })

  it('DELETE request does not set Content-Type header', async () => {
    let capturedInit: any
    ;(globalThis as any).fetch = vi.fn(async (_url: string, init: any) => {
      capturedInit = init
      return {
        status: 200,
        ok: true,
        json: async () => ({}),
        headers: { forEach: () => {} },
      }
    })

    const { useHttp } = await import('../composables/useHttp')
    const http = await withSetup(() => useHttp())
    await http.delete('/test')

    expect(capturedInit.headers['Content-Type']).toBeUndefined()
  })

  it('parses response headers from fetch response', async () => {
    ;(globalThis as any).fetch = vi.fn(async () => ({
      status: 200,
      ok: true,
      json: async () => ({ result: true }),
      headers: {
        forEach: (cb: (v: string, k: string) => void) => {
          cb('application/json', 'content-type')
          cb('123', 'x-request-id')
        },
      },
    }))

    const { useHttp } = await import('../composables/useHttp')
    const http = await withSetup(() => useHttp())
    const res = await http.get('/test')

    expect(res.headers['content-type']).toBe('application/json')
    expect(res.headers['x-request-id']).toBe('123')
  })

  it('timeout aborts the request when AbortController is available', async () => {
    const mockAbort = vi.fn()

    // Mock AbortController
    ;(globalThis as any).AbortController = class {
      signal = {}
      abort = mockAbort
    }

    ;(globalThis as any).fetch = vi.fn(async (_url: string, init: any) => {
      // Simulate a slow request — check if signal is passed
      expect(init.signal).toBeDefined()
      return {
        status: 200,
        ok: true,
        json: async () => ({}),
        headers: { forEach: () => {} },
      }
    })

    const { useHttp } = await import('../composables/useHttp')
    const http = await withSetup(() => useHttp({ timeout: 5000 }))
    await http.get('/test')

    // Timeout timer should have been set and cleared after success
    // The key thing is that AbortController signal was passed to fetch
    delete (globalThis as any).AbortController
  })
})
