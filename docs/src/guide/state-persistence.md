# State Persistence

Vue Native provides several mechanisms for persisting state across app launches: automatic navigation state restoration, key-value storage, encrypted storage for sensitive data, and a local SQLite database for structured data.

## Navigation State Persistence

The Vue Native router can automatically save and restore the navigation stack so users return to the exact screen they left.

### Configuration

Enable state persistence by setting `persistState: true` in your router options:

```ts
import { createApp } from '@thelacanians/vue-native-runtime'
import { createRouter } from '@thelacanians/vue-native-navigation'
import App from './App.vue'
import Home from './screens/Home.vue'
import Profile from './screens/Profile.vue'
import Settings from './screens/Settings.vue'

const router = createRouter({
  routes: [
    { name: 'home', component: Home },
    { name: 'profile', component: Profile },
    { name: 'settings', component: Settings },
  ],
  persistState: true,
  // Optional: customize the storage key (defaults to '__vue_native_nav_state__')
  persistKey: 'my_app_nav_state',
})

createApp(App).use(router).start()
```

### How It Works

When `persistState` is enabled, the router:

1. **On creation** -- Reads the saved state from `AsyncStorage` using the `persistKey` and calls `restoreState()` to rebuild the navigation stack.
2. **On navigation changes** -- Watches the stack for changes and saves the current state to `AsyncStorage`, debounced by 300ms to avoid excessive writes.

The state is serialized as JSON with the following structure:

```ts
interface NavigationState {
  stack: Array<{ name: string; params: Record<string, any> }>
  index: number
}
```

### What Gets Saved

| Saved | Not Saved |
|-------|-----------|
| Screen names | Component instances |
| Route params (serializable values) | Functions in params |
| Stack order and current index | Symbols in params |
| | Reactive state inside components |

::: warning
Only JSON-serializable values in route params are persisted. If a route param contains a function or a Symbol, it will be lost on restore. In development mode, the router logs a warning for each non-serializable param:

```
[vue-native/navigation] Route "profile" has non-serializable param "onUpdate" (function).
This value will be lost during state persistence.
```
:::

### Manual State Control

You can also use `getState()` and `restoreState()` directly for custom persistence strategies:

```ts
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()

// Snapshot the current navigation state
const state = router.getState()
// { stack: [{ name: 'home', params: {} }, { name: 'profile', params: { id: '42' } }], index: 1 }

// Restore a previously saved state
router.restoreState(state)
```

`restoreState()` validates every route name against the registered routes. If a route name no longer exists (for example, after an app update that renamed a screen), the router resets to the initial route and logs a warning:

```
[vue-native/navigation] Route "old-screen" not found in restoreState, resetting to initial
```

If the state object is invalid (null, not an array, or empty), `restoreState()` is a no-op:

```
[vue-native/navigation] Invalid state, ignoring restoreState
```

## App State Persistence

Beyond navigation, you will often need to persist user preferences, tokens, or application data. Vue Native provides three storage composables at different levels of complexity.

### Key-Value Storage with `useAsyncStorage`

`useAsyncStorage` provides simple string-based key-value storage backed by `UserDefaults` (iOS) and `SharedPreferences` (Android). It is ideal for user preferences, feature flags, and small pieces of data.

```vue
<script setup>
import { ref, onMounted } from '@thelacanians/vue-native-runtime'
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
```

**API:**

| Method | Return Type | Description |
|--------|-------------|-------------|
| `getItem(key)` | `Promise<string \| null>` | Read a value by key |
| `setItem(key, value)` | `Promise<void>` | Write a string value |
| `removeItem(key)` | `Promise<void>` | Delete a key |
| `getAllKeys()` | `Promise<string[]>` | List all stored keys |
| `clear()` | `Promise<void>` | Remove all entries |

::: tip
Write operations (`setItem`, `removeItem`) are serialized per key. If you call `setItem('theme', 'dark')` and `setItem('theme', 'light')` in quick succession, they execute in order -- the second write waits for the first to complete. This prevents race conditions from concurrent access.
:::

All values must be strings. For objects, serialize with `JSON.stringify` and deserialize with `JSON.parse`:

```ts
// Save an object
await storage.setItem('preferences', JSON.stringify({ fontSize: 16, lang: 'en' }))

// Load an object
const raw = await storage.getItem('preferences')
const prefs = raw ? JSON.parse(raw) : { fontSize: 14, lang: 'en' }
```

### Secure Storage with `useSecureStorage`

`useSecureStorage` stores data in the iOS Keychain or Android EncryptedSharedPreferences. Use it for auth tokens, API keys, and any sensitive information.

```vue
<script setup>
import { useSecureStorage } from '@thelacanians/vue-native-runtime'

const secureStorage = useSecureStorage()

async function saveToken(token: string) {
  await secureStorage.setItem('auth_token', token)
}

async function getToken(): Promise<string | null> {
  return secureStorage.getItem('auth_token')
}

async function logout() {
  await secureStorage.removeItem('auth_token')
}
</script>
```

**API:**

| Method | Return Type | Description |
|--------|-------------|-------------|
| `getItem(key)` | `Promise<string \| null>` | Read a secure value |
| `setItem(key, value)` | `Promise<void>` | Write a secure value |
| `removeItem(key)` | `Promise<void>` | Delete a secure entry |
| `clear()` | `Promise<void>` | Remove all secure entries |

::: warning
Secure storage is slower than `useAsyncStorage` because of the encryption overhead. Only use it for data that genuinely requires protection. User preferences and UI state should use `useAsyncStorage` instead.
:::

### Structured Data with `useDatabase`

`useDatabase` provides reactive SQLite access for structured or relational data. The database opens on first use and auto-closes when the component unmounts.

```vue
<script setup>
import { ref, onMounted } from '@thelacanians/vue-native-runtime'
import { useDatabase } from '@thelacanians/vue-native-runtime'

interface Todo {
  id: number
  title: string
  done: number
}

const db = useDatabase('todos')
const items = ref<Todo[]>([])

onMounted(async () => {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY, title TEXT, done INTEGER DEFAULT 0)'
  )
  items.value = await db.query<Todo>('SELECT * FROM todos ORDER BY id DESC')
})

async function addTodo(title: string) {
  await db.execute('INSERT INTO todos (title) VALUES (?)', [title])
  items.value = await db.query<Todo>('SELECT * FROM todos ORDER BY id DESC')
}

async function toggleTodo(id: number, done: boolean) {
  await db.execute('UPDATE todos SET done = ? WHERE id = ?', [done ? 1 : 0, id])
  items.value = await db.query<Todo>('SELECT * FROM todos ORDER BY id DESC')
}
</script>
```

**API:**

| Method | Return Type | Description |
|--------|-------------|-------------|
| `execute(sql, params?)` | `Promise<ExecuteResult>` | Run an INSERT, UPDATE, or DELETE statement |
| `query<T>(sql, params?)` | `Promise<T[]>` | Run a SELECT and return rows |
| `transaction(callback)` | `Promise<void>` | Execute multiple statements atomically |
| `close()` | `Promise<void>` | Manually close the database |
| `isOpen` | `Ref<boolean>` | Whether the database is currently open |

Transactions ensure atomicity -- if any statement fails, all changes are rolled back:

```ts
await db.transaction(async ({ execute }) => {
  await execute('INSERT INTO todos (title) VALUES (?)', ['Buy groceries'])
  await execute('INSERT INTO todos (title) VALUES (?)', ['Walk the dog'])
  // If either INSERT fails, both are rolled back
})
```

## State Management Patterns

Vue Native does not ship a dedicated state management library. Instead, use Vue 3's built-in reactivity with `reactive()` and `provide/inject` to share state across screens.

### Reactive Store Pattern

Create a composable that returns a reactive store and provide it at the app level:

```ts
// stores/auth.ts
import { reactive, readonly } from '@thelacanians/vue-native-runtime'
import { useSecureStorage } from '@thelacanians/vue-native-runtime'

interface AuthState {
  isLoggedIn: boolean
  user: { id: string; name: string } | null
  token: string | null
}

const state = reactive<AuthState>({
  isLoggedIn: false,
  user: null,
  token: null,
})

const secureStorage = useSecureStorage()

export function useAuthStore() {
  async function login(email: string, password: string) {
    // Call your API
    const response = await fetch('https://api.example.com/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    })
    const data = await response.json()

    state.token = data.token
    state.user = data.user
    state.isLoggedIn = true

    // Persist the token securely
    await secureStorage.setItem('auth_token', data.token)
  }

  async function logout() {
    state.token = null
    state.user = null
    state.isLoggedIn = false
    await secureStorage.removeItem('auth_token')
  }

  async function restoreSession() {
    const token = await secureStorage.getItem('auth_token')
    if (token) {
      state.token = token
      state.isLoggedIn = true
      // Optionally fetch user profile
    }
  }

  return {
    state: readonly(state),
    login,
    logout,
    restoreSession,
  }
}
```

### Sharing State Between Screens

Use `provide` at the root component and `inject` in child screens:

```vue
<!-- App.vue -->
<script setup>
import { provide } from '@thelacanians/vue-native-runtime'
import { useAuthStore } from './stores/auth'

const authStore = useAuthStore()
provide('auth', authStore)

// Restore session on app launch
authStore.restoreSession()
</script>

<template>
  <RouterView />
</template>
```

```vue
<!-- screens/Profile.vue -->
<script setup>
import { inject } from '@thelacanians/vue-native-runtime'

const auth = inject('auth')
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VText :style="{ fontSize: 20 }">
      Welcome, {{ auth.state.user?.name ?? 'Guest' }}
    </VText>
    <VButton :onPress="auth.logout">
      <VText>Log Out</VText>
    </VButton>
  </VView>
</template>
```

### Persisting User Preferences

A common pattern combines `useAsyncStorage` with a reactive store for preferences that survive app restarts:

```ts
// stores/preferences.ts
import { reactive, watch } from '@thelacanians/vue-native-runtime'
import { useAsyncStorage } from '@thelacanians/vue-native-runtime'

const STORAGE_KEY = 'user_preferences'

interface Preferences {
  theme: 'light' | 'dark'
  fontSize: number
  notificationsEnabled: boolean
}

const defaults: Preferences = {
  theme: 'light',
  fontSize: 16,
  notificationsEnabled: true,
}

const state = reactive<Preferences>({ ...defaults })
const storage = useAsyncStorage()
let initialized = false

export function usePreferences() {
  async function load() {
    if (initialized) return
    const raw = await storage.getItem(STORAGE_KEY)
    if (raw) {
      try {
        Object.assign(state, JSON.parse(raw))
      } catch {
        // Corrupted data -- use defaults
      }
    }
    initialized = true
  }

  // Auto-save when any preference changes
  watch(state, async () => {
    if (!initialized) return
    await storage.setItem(STORAGE_KEY, JSON.stringify(state))
  }, { deep: true })

  return { preferences: state, load }
}
```

Use it from your root component:

```vue
<!-- App.vue -->
<script setup>
import { provide } from '@thelacanians/vue-native-runtime'
import { usePreferences } from './stores/preferences'

const { preferences, load } = usePreferences()
provide('preferences', preferences)

load() // Restore on launch
</script>
```

### Choosing the Right Storage

| Use Case | Recommended Storage | Composable |
|----------|-------------------|------------|
| User preferences (theme, language) | AsyncStorage | `useAsyncStorage` |
| Auth tokens, API keys | Secure Storage | `useSecureStorage` |
| Navigation stack | Built-in persistence | `persistState: true` |
| Structured app data (todos, messages) | SQLite | `useDatabase` |
| Temporary UI state (form inputs) | Vue `ref`/`reactive` | None needed |

## See Also

- [useAsyncStorage reference](/composables/useAsyncStorage.md)
- [Navigation guide](/guide/navigation.md)
- [Navigation params](/navigation/params.md)
