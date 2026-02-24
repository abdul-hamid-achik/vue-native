/**
 * useIAP tests — verifies that the IAP composable calls the correct
 * NativeBridge module/method and handles reactive state and errors.
 */
import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { installMockBridge } from './helpers'

const mockBridge = installMockBridge()

const { NativeBridge } = await import('../bridge')

let invokeModuleSpy: ReturnType<typeof vi.spyOn>
let onGlobalEventSpy: ReturnType<typeof vi.spyOn>

const globalEventHandlers: Map<string, Array<(payload: any) => void>> = new Map()

describe('useIAP', () => {
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

  it('initializes billing client on creation', async () => {
    const { useIAP } = await import('../composables/useIAP')
    useIAP()
    expect(invokeModuleSpy).toHaveBeenCalledWith('IAP', 'initialize')
  })

  it('sets isReady to true after successful initialization', async () => {
    invokeModuleSpy.mockImplementation((module: string, method: string) => {
      if (module === 'IAP' && method === 'initialize') return Promise.resolve(undefined)
      return Promise.resolve(undefined as any)
    })
    const { useIAP } = await import('../composables/useIAP')
    const { isReady } = useIAP()
    await Promise.resolve()
    await Promise.resolve()
    expect(isReady.value).toBe(true)
  })

  it('subscribes to iap:transactionUpdate global event', async () => {
    const { useIAP } = await import('../composables/useIAP')
    useIAP()
    expect(onGlobalEventSpy).toHaveBeenCalledWith('iap:transactionUpdate', expect.any(Function))
  })

  it('getProducts calls IAP.getProducts with SKU array', async () => {
    const mockProducts = [
      { id: 'com.app.premium', displayName: 'Premium', price: 9.99, displayPrice: '$9.99' },
    ]
    invokeModuleSpy.mockImplementation((module: string, method: string) => {
      if (module === 'IAP' && method === 'getProducts') return Promise.resolve(mockProducts)
      return Promise.resolve(undefined as any)
    })

    const { useIAP } = await import('../composables/useIAP')
    const { getProducts, products } = useIAP()
    const result = await getProducts(['com.app.premium'])
    expect(invokeModuleSpy).toHaveBeenCalledWith('IAP', 'getProducts', [['com.app.premium']])
    expect(result).toEqual(mockProducts)
    expect(products.value).toEqual(mockProducts)
  })

  it('purchase calls IAP.purchase with SKU string', async () => {
    const mockPurchase = { productId: 'com.app.premium', transactionId: 'txn123' }
    invokeModuleSpy.mockImplementation((module: string, method: string) => {
      if (module === 'IAP' && method === 'purchase') return Promise.resolve(mockPurchase)
      return Promise.resolve(undefined as any)
    })

    const { useIAP } = await import('../composables/useIAP')
    const { purchase } = useIAP()
    const result = await purchase('com.app.premium')
    expect(invokeModuleSpy).toHaveBeenCalledWith('IAP', 'purchase', ['com.app.premium'])
    expect(result).toEqual(mockPurchase)
  })

  it('purchase sets error on failure', async () => {
    invokeModuleSpy.mockImplementation((module: string, method: string) => {
      if (module === 'IAP' && method === 'purchase') return Promise.reject('user cancelled')
      return Promise.resolve(undefined as any)
    })

    const { useIAP } = await import('../composables/useIAP')
    const { purchase, error } = useIAP()
    const result = await purchase('com.app.premium')
    expect(result).toBeNull()
    expect(error.value).toBe('user cancelled')
  })

  it('restorePurchases calls IAP.restorePurchases', async () => {
    const restored = [{ productId: 'com.app.premium', transactionId: 'txn456' }]
    invokeModuleSpy.mockImplementation((module: string, method: string) => {
      if (module === 'IAP' && method === 'restorePurchases') return Promise.resolve(restored)
      return Promise.resolve(undefined as any)
    })

    const { useIAP } = await import('../composables/useIAP')
    const { restorePurchases } = useIAP()
    const result = await restorePurchases()
    expect(invokeModuleSpy).toHaveBeenCalledWith('IAP', 'restorePurchases')
    expect(result).toEqual(restored)
  })

  it('getActiveSubscriptions calls IAP.getActiveSubscriptions', async () => {
    const active = [{ productId: 'com.app.monthly', transactionId: 'txn789', expiresDate: '2026-03-01' }]
    invokeModuleSpy.mockImplementation((module: string, method: string) => {
      if (module === 'IAP' && method === 'getActiveSubscriptions') return Promise.resolve(active)
      return Promise.resolve(undefined as any)
    })

    const { useIAP } = await import('../composables/useIAP')
    const { getActiveSubscriptions } = useIAP()
    const result = await getActiveSubscriptions()
    expect(invokeModuleSpy).toHaveBeenCalledWith('IAP', 'getActiveSubscriptions')
    expect(result).toEqual(active)
  })

  it('updates error on iap:transactionUpdate with failed state', async () => {
    const { useIAP } = await import('../composables/useIAP')
    const { error } = useIAP()

    triggerGlobalEvent('iap:transactionUpdate', {
      productId: 'com.app.premium',
      state: 'failed',
      error: 'Payment declined',
    })
    expect(error.value).toBe('Payment declined')
  })

  it('onTransactionUpdate registers custom callback', async () => {
    const { useIAP } = await import('../composables/useIAP')
    const { onTransactionUpdate } = useIAP()
    const handler = vi.fn()
    onTransactionUpdate(handler)

    const update = { productId: 'com.app.premium', state: 'purchased', transactionId: 'txn999' }
    triggerGlobalEvent('iap:transactionUpdate', update)
    expect(handler).toHaveBeenCalledWith(update)
  })

  it('restorePurchases sets error on failure', async () => {
    invokeModuleSpy.mockImplementation((module: string, method: string) => {
      if (module === 'IAP' && method === 'restorePurchases') return Promise.reject('network error')
      return Promise.resolve(undefined as any)
    })

    const { useIAP } = await import('../composables/useIAP')
    const { restorePurchases, error } = useIAP()
    const result = await restorePurchases()
    expect(result).toEqual([])
    expect(error.value).toBe('network error')
  })
})
