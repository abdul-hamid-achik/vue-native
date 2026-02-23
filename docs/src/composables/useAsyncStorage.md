# useAsyncStorage

Persistent key-value storage. All operations are asynchronous and backed by the platform's native storage mechanism. Useful for persisting user preferences, tokens, cached data, and other small values across app launches.

## Usage

```vue
<script setup>
import { ref, onMounted } from 'vue'
import { useAsyncStorage } from '@thelacanians/vue-native-runtime'

const storage = useAsyncStorage()
const username = ref('')

onMounted(async () => {
  username.value = (await storage.getItem('username')) ?? 'Guest'
})
</script>
```

## API

```ts
useAsyncStorage(): {
  getItem: (key: string) => Promise<string | null>
  setItem: (key: string, value: string) => Promise<void>
  removeItem: (key: string) => Promise<void>
  getAllKeys: () => Promise<string[]>
  clear: () => Promise<void>
}
```

### Return Value

| Method | Signature | Description |
|--------|-----------|-------------|
| `getItem` | `(key: string) => Promise<string \| null>` | Retrieve a value by key. Returns `null` if the key does not exist. |
| `setItem` | `(key: string, value: string) => Promise<void>` | Store a string value under the given key. Overwrites any existing value. |
| `removeItem` | `(key: string) => Promise<void>` | Delete a single key-value pair. |
| `getAllKeys` | `() => Promise<string[]>` | Return an array of all stored keys. |
| `clear` | `() => Promise<void>` | Remove all key-value pairs from storage. |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Backed by `UserDefaults`. |
| Android | Backed by `SharedPreferences`. |

## Example

```vue
<script setup>
import { ref, onMounted } from 'vue'
import { useAsyncStorage } from '@thelacanians/vue-native-runtime'

const storage = useAsyncStorage()
const theme = ref('light')

onMounted(async () => {
  const saved = await storage.getItem('theme')
  if (saved) theme.value = saved
})

async function toggleTheme() {
  theme.value = theme.value === 'light' ? 'dark' : 'light'
  await storage.setItem('theme', theme.value)
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText :style="{ fontSize: 18, marginBottom: 12 }">
      Current theme: {{ theme }}
    </VText>
    <VButton title="Toggle Theme" :onPress="toggleTheme" />
  </VView>
</template>
```

## Notes

- All values must be strings. To store objects, serialize with `JSON.stringify()` and deserialize with `JSON.parse()`.
- Operations run on a background thread natively and return Promises, so they will not block the UI.
- This composable has no reactive state and no cleanup — it simply returns async functions. It is safe to call from anywhere, including outside `setup()`.
- For large datasets or structured data, consider a dedicated database solution instead.
