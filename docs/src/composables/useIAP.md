# useIAP

In-App Purchases composable backed by StoreKit 2 (iOS) and Google Play Billing Library (Android). Supports one-time purchases, subscriptions, restoring purchases, and transaction monitoring.

## Setup

### iOS

No additional setup required. StoreKit 2 is built into iOS 15+. Configure your products in App Store Connect.

### Android

Add the Google Play Billing Library to your `build.gradle`:

```groovy
dependencies {
    implementation 'com.android.billingclient:billing:6.0.1'
}
```

Configure your products in the Google Play Console.

## Usage

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useIAP } from '@thelacanians/vue-native-runtime'

const { products, getProducts, purchase, restorePurchases, isReady, error } = useIAP()

// Load products when ready
async function loadProducts() {
  await getProducts(['com.myapp.premium', 'com.myapp.coins100'])
}

async function buyPremium() {
  const result = await purchase('com.myapp.premium')
  if (result) {
    console.log('Purchased:', result.transactionId)
  }
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VButton :onPress="loadProducts">
      <VText>Load Products</VText>
    </VButton>

    <VView v-for="product in products" :key="product.id" :style="{ marginTop: 10 }">
      <VText>{{ product.displayName }} - {{ product.displayPrice }}</VText>
      <VButton :onPress="() => purchase(product.id)">
        <VText>Buy</VText>
      </VButton>
    </VView>

    <VText v-if="error" :style="{ color: 'red', marginTop: 10 }">{{ error }}</VText>
  </VView>
</template>
```

## API

```ts
useIAP(): {
  products: Ref<Product[]>
  isReady: Ref<boolean>
  error: Ref<string | null>
  getProducts: (skus: string[]) => Promise<Product[]>
  purchase: (sku: string) => Promise<Purchase | null>
  restorePurchases: () => Promise<Purchase[]>
  getActiveSubscriptions: () => Promise<Purchase[]>
  onTransactionUpdate: (callback: (update: TransactionUpdate) => void) => () => void
}
```

### Reactive State

| Property | Type | Description |
|----------|------|-------------|
| `products` | `Ref<Product[]>` | Products loaded by `getProducts()`. Updated reactively. |
| `isReady` | `Ref<boolean>` | `true` once the billing client is initialized. |
| `error` | `Ref<string \| null>` | Last error message, or `null`. Cleared before each operation. |

### Methods

#### `getProducts(skus)`

Fetch product information from the store.

| Parameter | Type | Description |
|-----------|------|-------------|
| `skus` | `string[]` | Array of product identifiers to fetch. |

Returns `Promise<Product[]>`. Also updates the reactive `products` ref.

#### `purchase(sku)`

Initiate a purchase flow for the given product.

| Parameter | Type | Description |
|-----------|------|-------------|
| `sku` | `string` | Product identifier to purchase. |

Returns `Promise<Purchase | null>`. Returns `null` on failure (error set in `error` ref).

#### `restorePurchases()`

Restore all previous purchases. Useful for users who reinstall the app or switch devices.

Returns `Promise<Purchase[]>`.

#### `getActiveSubscriptions()`

Get all currently active auto-renewable subscriptions.

Returns `Promise<Purchase[]>`.

#### `onTransactionUpdate(callback)`

Register a callback for transaction state changes. Useful for monitoring pending transactions.

| Parameter | Type | Description |
|-----------|------|-------------|
| `callback` | `(update: TransactionUpdate) => void` | Called when a transaction state changes. |

Returns a cleanup function to unsubscribe.

### Types

#### Product

| Property | Type | Description |
|----------|------|-------------|
| `id` | `string` | Product identifier (SKU). |
| `displayName` | `string` | Localized product name. |
| `description` | `string` | Localized product description. |
| `price` | `number` | Price as a number. |
| `displayPrice` | `string` | Formatted price string (e.g. "$9.99"). |
| `currencyCode` | `string` | ISO 4217 currency code. |
| `type` | `ProductType` | Product type. |

#### ProductType

`'consumable' | 'nonConsumable' | 'autoRenewable' | 'nonRenewable'`

#### Purchase

| Property | Type | Description |
|----------|------|-------------|
| `productId` | `string` | The purchased product's identifier. |
| `transactionId` | `string` | Unique transaction identifier. |
| `originalTransactionId` | `string?` | Original transaction ID (for renewals). |
| `purchaseDate` | `string` | ISO 8601 purchase date. |
| `expiresDate` | `string?` | Expiration date for subscriptions. |

#### TransactionUpdate

| Property | Type | Description |
|----------|------|-------------|
| `productId` | `string` | Product identifier. |
| `state` | `TransactionState` | Current state of the transaction. |
| `transactionId` | `string?` | Transaction identifier. |
| `error` | `string?` | Error message if state is `'failed'`. |

#### TransactionState

`'purchasing' | 'purchased' | 'failed' | 'restored' | 'deferred'`

## Restore Purchases Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useIAP } from '@thelacanians/vue-native-runtime'

const { restorePurchases, error } = useIAP()
const restoredCount = ref(0)

async function handleRestore() {
  const restored = await restorePurchases()
  restoredCount.value = restored.length
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VButton :onPress="handleRestore">
      <VText>Restore Purchases</VText>
    </VButton>
    <VText v-if="restoredCount > 0">Restored {{ restoredCount }} purchase(s)</VText>
    <VText v-if="error" :style="{ color: 'red' }">{{ error }}</VText>
  </VView>
</template>
```

## Subscription Example

```vue
<script setup>
import { ref, onMounted } from '@thelacanians/vue-native-runtime'
import { useIAP } from '@thelacanians/vue-native-runtime'

const { getProducts, purchase, getActiveSubscriptions, products, error } = useIAP()
const activeSubs = ref([])

onMounted(async () => {
  await getProducts(['com.myapp.monthly', 'com.myapp.yearly'])
  activeSubs.value = await getActiveSubscriptions()
})

async function subscribe(sku) {
  const result = await purchase(sku)
  if (result) {
    activeSubs.value = await getActiveSubscriptions()
  }
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VText :style="{ fontSize: 20, fontWeight: 'bold' }">Subscriptions</VText>

    <VView v-for="product in products" :key="product.id" :style="{ marginTop: 10 }">
      <VText>{{ product.displayName }} - {{ product.displayPrice }}</VText>
      <VButton :onPress="() => subscribe(product.id)">
        <VText>Subscribe</VText>
      </VButton>
    </VView>

    <VText :style="{ marginTop: 20, fontWeight: 'bold' }">
      Active Subscriptions: {{ activeSubs.length }}
    </VText>
  </VView>
</template>
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | StoreKit 2. Requires iOS 15.0+. |
| Android | Google Play Billing Library 6.x. |

## Notes

- The billing client is automatically initialized when `useIAP()` is called. Check `isReady` before making purchases.
- All methods clear the `error` ref before executing. Check `error` after each call for failure details.
- On iOS, transactions are automatically verified using StoreKit 2's built-in verification.
- On Android, purchases are automatically acknowledged after successful purchase.
- The `onTransactionUpdate` callback fires for server-side transaction updates (e.g., subscription renewals, refunds).
- Always call `getProducts()` before `purchase()` to populate the product cache.
