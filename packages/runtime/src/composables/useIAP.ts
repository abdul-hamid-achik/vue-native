import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// ─── Types ────────────────────────────────────────────────────────────────

export type ProductType = 'consumable' | 'nonConsumable' | 'autoRenewable' | 'nonRenewable'

export type TransactionState = 'purchasing' | 'purchased' | 'failed' | 'restored' | 'deferred'

export interface Product {
  id: string
  displayName: string
  description: string
  price: number
  displayPrice: string
  currencyCode: string
  type: ProductType
}

export interface Purchase {
  productId: string
  transactionId: string
  originalTransactionId?: string
  purchaseDate: string
  expiresDate?: string
}

export interface TransactionUpdate {
  productId: string
  state: TransactionState
  transactionId?: string
  error?: string
}

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null && 'message' in error) {
    const message = (error as { message?: unknown }).message
    if (typeof message === 'string') return message
  }
  return String(error)
}

// ─── useIAP composable ───────────────────────────────────────────────────

/**
 * In-App Purchases composable backed by StoreKit 2 (iOS) and Google Play Billing (Android).
 *
 * @example
 * const { products, getProducts, purchase, restorePurchases, isReady, error } = useIAP()
 *
 * // Load products
 * await getProducts(['com.app.premium', 'com.app.coins100'])
 *
 * // Purchase
 * const result = await purchase('com.app.premium')
 *
 * // Restore
 * const restored = await restorePurchases()
 */
export function useIAP() {
  const products = ref<Product[]>([])
  const isReady = ref(false)
  const error = ref<string | null>(null)

  const cleanups: Array<() => void> = []

  // Listen for transaction updates
  const unsubscribe = NativeBridge.onGlobalEvent('iap:transactionUpdate', (payload: TransactionUpdate) => {
    if (payload.state === 'failed' && payload.error) {
      error.value = payload.error
    }
  })
  cleanups.push(unsubscribe)

  // Initialize billing client
  NativeBridge.invokeNativeModule('IAP', 'initialize')
    .then(() => { isReady.value = true })
    .catch((err: unknown) => { error.value = getErrorMessage(err) })

  async function getProducts(skus: string[]): Promise<Product[]> {
    error.value = null
    try {
      const result = await NativeBridge.invokeNativeModule('IAP', 'getProducts', [skus])
      const productList = result as Product[]
      products.value = productList
      return productList
    } catch (err: unknown) {
      error.value = getErrorMessage(err)
      return []
    }
  }

  async function purchase(sku: string): Promise<Purchase | null> {
    error.value = null
    try {
      return await NativeBridge.invokeNativeModule('IAP', 'purchase', [sku])
    } catch (err: unknown) {
      error.value = getErrorMessage(err)
      return null
    }
  }

  async function restorePurchases(): Promise<Purchase[]> {
    error.value = null
    try {
      return await NativeBridge.invokeNativeModule('IAP', 'restorePurchases')
    } catch (err: unknown) {
      error.value = getErrorMessage(err)
      return []
    }
  }

  async function getActiveSubscriptions(): Promise<Purchase[]> {
    error.value = null
    try {
      return await NativeBridge.invokeNativeModule('IAP', 'getActiveSubscriptions')
    } catch (err: unknown) {
      error.value = getErrorMessage(err)
      return []
    }
  }

  function onTransactionUpdate(callback: (update: TransactionUpdate) => void): () => void {
    const unsub = NativeBridge.onGlobalEvent('iap:transactionUpdate', callback)
    cleanups.push(unsub)
    return unsub
  }

  onUnmounted(() => {
    cleanups.forEach(fn => fn())
    cleanups.length = 0
  })

  return {
    products,
    isReady,
    error,
    getProducts,
    purchase,
    restorePurchases,
    getActiveSubscriptions,
    onTransactionUpdate,
  }
}
