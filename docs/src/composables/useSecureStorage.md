# useSecureStorage

Encrypted key-value storage. Backed by Keychain on iOS and EncryptedSharedPreferences on Android. Use this for sensitive data like authentication tokens, API keys, and user credentials.

## Usage

```vue
<script setup>
import { ref, onMounted } from '@thelacanians/vue-native-runtime'
import { useSecureStorage } from '@thelacanians/vue-native-runtime'

const secureStorage = useSecureStorage()
const token = ref('')

onMounted(async () => {
  token.value = (await secureStorage.getItem('authToken')) ?? ''
})
</script>
```

## API

```ts
useSecureStorage(): {
  getItem: (key: string) => Promise<string | null>
  setItem: (key: string, value: string) => Promise<void>
  removeItem: (key: string) => Promise<void>
  clear: () => Promise<void>
}
```

### Return Value

| Method | Signature | Description |
|--------|-----------|-------------|
| `getItem` | `(key: string) => Promise<string \| null>` | Retrieve a value by key. Returns `null` if the key does not exist. |
| `setItem` | `(key: string, value: string) => Promise<void>` | Store a string value securely under the given key. |
| `removeItem` | `(key: string) => Promise<void>` | Delete a single key-value pair. |
| `clear` | `() => Promise<void>` | Remove all secure key-value pairs. |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Backed by Keychain Services (`kSecClassGenericPassword`). Data persists across app reinstalls. |
| Android | Backed by `EncryptedSharedPreferences` (AndroidX Security). Uses AES-256 encryption. |

## Example

```vue
<script setup>
import { ref, onMounted } from '@thelacanians/vue-native-runtime'
import { useSecureStorage } from '@thelacanians/vue-native-runtime'

const secureStorage = useSecureStorage()
const isLoggedIn = ref(false)

onMounted(async () => {
  const token = await secureStorage.getItem('authToken')
  isLoggedIn.value = token !== null
})

async function login(token: string) {
  await secureStorage.setItem('authToken', token)
  isLoggedIn.value = true
}

async function logout() {
  await secureStorage.removeItem('authToken')
  isLoggedIn.value = false
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText :style="{ fontSize: 18, marginBottom: 12 }">
      {{ isLoggedIn ? 'Logged in' : 'Logged out' }}
    </VText>
    <VButton :onPress="() => isLoggedIn ? logout() : login('token123')">
      <VText>{{ isLoggedIn ? 'Logout' : 'Login' }}</VText>
    </VButton>
  </VView>
</template>
```

## useSecureStorage vs useAsyncStorage

| Feature | useAsyncStorage | useSecureStorage |
|---------|-----------------|------------------|
| Backend | UserDefaults / SharedPreferences | Keychain / EncryptedSharedPreferences |
| Encryption | None | AES-256 |
| Persists on reinstall | No | Yes (iOS Keychain) |
| Use for | Preferences, cache | Tokens, credentials, secrets |
| `getAllKeys()` | Yes | No |

## Notes

- All values must be strings. Serialize objects with `JSON.stringify()` before storing.
- Operations run on a background thread and return Promises.
- On iOS, Keychain items persist across app reinstalls by default. Call `clear()` on first launch if you want a fresh start after reinstall.
- This composable has no reactive state and no cleanup -- it returns async functions only.
