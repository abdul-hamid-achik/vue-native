# State Management

## Local State

For single-component state, Vue's Composition API is all you need:

```ts
import { ref, reactive, computed } from '@thelacanians/vue-native-runtime'

const count = ref(0)
const user = reactive({ name: 'Alice', email: 'alice@example.com' })
const displayName = computed(() => user.name.toUpperCase())
```

## Sharing State Across Components

### provide / inject

For state shared within a component subtree (parent and all descendants), use `provide` and `inject`:

```ts
// Parent component
import { provide, ref } from '@thelacanians/vue-native-runtime'

const user = ref({ name: 'Alice', loggedIn: true })
provide('user', user)
```

```ts
// Any descendant component
import { inject } from '@thelacanians/vue-native-runtime'

const user = inject('user')
```

### Composable Pattern

For reusable state that multiple components share, create a composable with module-level state:

```ts
// composables/useAuth.ts
import { ref, readonly } from '@thelacanians/vue-native-runtime'

const user = ref<{ name: string; token: string } | null>(null)
const isLoggedIn = ref(false)

export function useAuth() {
  async function login(email: string, password: string) {
    // Call your API...
    user.value = { name: 'Alice', token: 'abc123' }
    isLoggedIn.value = true
  }

  function logout() {
    user.value = null
    isLoggedIn.value = false
  }

  return {
    user: readonly(user),
    isLoggedIn: readonly(isLoggedIn),
    login,
    logout,
  }
}
```

```vue
<!-- Any component -->
<script setup>
import { useAuth } from '../composables/useAuth'
const { user, isLoggedIn, logout } = useAuth()
</script>
```

This pattern works because ES module state is shared across all imports — every component that calls `useAuth()` gets the same `user` and `isLoggedIn` refs.

## Pinia

[Pinia](https://pinia.vuejs.org/) is the official Vue state management library and works with Vue Native.

### Setup

Install Pinia in your project:

```bash
bun add pinia
```

Register the Pinia plugin in your entry point:

```ts
// app/main.ts
import { createApp } from '@thelacanians/vue-native-runtime'
import { createPinia } from 'pinia'
import App from './App.vue'

const app = createApp(App)
app.use(createPinia())
app.start()
```

### Define a Store

```ts
// stores/counter.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useCounterStore = defineStore('counter', () => {
  const count = ref(0)
  const doubleCount = computed(() => count.value * 2)

  function increment() {
    count.value++
  }

  function decrement() {
    count.value--
  }

  return { count, doubleCount, increment, decrement }
})
```

### Use in Components

```vue
<script setup>
import { useCounterStore } from '../stores/counter'
import { storeToRefs } from 'pinia'

const store = useCounterStore()
const { count, doubleCount } = storeToRefs(store)
</script>

<template>
  <VView :style="{ flex: 1, alignItems: 'center', justifyContent: 'center' }">
    <VText :style="{ fontSize: 48 }">{{ count }}</VText>
    <VText :style="{ fontSize: 16, color: '#8E8E93' }">Double: {{ doubleCount }}</VText>
    <VButton :onPress="store.increment">
      <VText>Increment</VText>
    </VButton>
    <VButton :onPress="store.decrement">
      <VText>Decrement</VText>
    </VButton>
  </VView>
</template>
```

### Why It Works

Vue Native's Vite plugin aliases `vue` → `@thelacanians/vue-native-runtime`, which re-exports all of `@vue/runtime-core` (including `effectScope`, `inject`, `provide`, `markRaw`, etc.). Since Pinia imports from `vue`, it receives the same Vue instance that the renderer uses. Vite's bundler deduplicates the dependency, ensuring a single copy.

### Persisting Store State

Combine Pinia with `useAsyncStorage` to persist state across app restarts:

```ts
// stores/settings.ts
import { defineStore } from 'pinia'
import { ref, watch } from 'vue'
import { useAsyncStorage } from '@thelacanians/vue-native-runtime'

export const useSettingsStore = defineStore('settings', () => {
  const { getItem, setItem } = useAsyncStorage()
  const theme = ref<'light' | 'dark'>('light')
  const fontSize = ref(16)

  // Load persisted state on store creation
  async function hydrate() {
    const saved = await getItem('settings')
    if (saved) {
      const data = JSON.parse(saved)
      theme.value = data.theme ?? 'light'
      fontSize.value = data.fontSize ?? 16
    }
  }

  // Persist on change
  watch([theme, fontSize], () => {
    setItem('settings', JSON.stringify({ theme: theme.value, fontSize: fontSize.value }))
  })

  hydrate()

  return { theme, fontSize }
})
```

## Recommendations

| Complexity | Solution |
|-----------|----------|
| Single component | `ref()`, `reactive()` |
| Parent → children sharing | `provide()` / `inject()` |
| Few cross-screen values (auth, theme) | Composable with module-level state |
| Complex app with many stores | Pinia |

For most Vue Native apps, the **composable pattern** is sufficient and has zero dependencies. Use Pinia when you need devtools support, store composition, or are already familiar with it from web Vue development.

::: warning Hot Reload
Hot reload resets all JavaScript state, including Pinia stores and composable module state. Use `useAsyncStorage` for critical state you need to survive reloads during development.
:::
