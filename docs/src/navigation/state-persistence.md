# State Persistence

Save and restore the navigation state across app launches. This is useful for resuming the user's position after the app is killed by the OS, or for crash recovery.

## API

### `router.getState()`

Returns a serializable snapshot of the current navigation state:

```ts
const state = router.getState()
// { stack: [{ name: 'home', params: {} }, { name: 'detail', params: { id: 42 } }], index: 1 }
```

### `router.restoreState(state)`

Restores a previously saved navigation state:

```ts
router.restoreState(savedState)
```

### NavigationState

```ts
interface NavigationState {
  stack: Array<{ name: string; params: Record<string, any> }>
  index: number
}
```

## Saving to AsyncStorage

A common pattern is to persist the navigation state to `AsyncStorage` whenever it changes:

```vue
<script setup>
import { watch, onMounted } from '@thelacanians/vue-native-runtime'
import { useAsyncStorage } from '@thelacanians/vue-native-runtime'
import { createRouter } from '@thelacanians/vue-native-navigation'
import HomeScreen from './pages/Home.vue'
import DetailScreen from './pages/Detail.vue'

const { getItem, setItem } = useAsyncStorage()
const STORAGE_KEY = 'nav-state'

const router = createRouter({
  routes: [
    { name: 'home', component: HomeScreen },
    { name: 'detail', component: DetailScreen },
  ],
})

// Restore state on mount
onMounted(async () => {
  const saved = await getItem(STORAGE_KEY)
  if (saved) {
    try {
      router.restoreState(JSON.parse(saved))
    } catch (e) {
      // Invalid state — start fresh
      console.warn('Failed to restore nav state:', e)
    }
  }
})

// Save state after every navigation
router.afterEach(() => {
  const state = router.getState()
  setItem(STORAGE_KEY, JSON.stringify(state))
})
</script>
```

## Auto-Persist with Router Options

For convenience, you can enable automatic state persistence via router options:

```ts
const router = createRouter({
  routes: [...],
  persistState: true,
  persistKey: 'my-app-nav',  // AsyncStorage key (default: 'vue-native-nav-state')
})
```

When `persistState` is `true`, the router automatically:
1. Saves state to AsyncStorage after each navigation
2. Restores state on initialization (if a saved state exists)

## Crash Recovery

Persisted state allows your app to recover gracefully from crashes or background termination:

```vue
<script setup>
import { useAsyncStorage } from '@thelacanians/vue-native-runtime'
import { createRouter } from '@thelacanians/vue-native-navigation'

const { getItem, removeItem } = useAsyncStorage()

const router = createRouter({
  routes: [...],
  persistState: true,
})

// Optional: clear persisted state on logout
async function logout() {
  await removeItem('vue-native-nav-state')
  router.reset('login')
}
</script>
```

## Notes

- `getState()` returns a plain JSON-serializable object. You can store it in `AsyncStorage`, `SecureStorage`, or send it to a server.
- `restoreState()` replaces the entire stack. Any screens in the restored state must be registered in the router's `routes` array.
- If a restored state references an unknown route name, `restoreState()` throws an error. Wrap it in a try-catch for safety.
- State persistence does not save component state (reactive data, scroll positions, etc.) — only the navigation stack and route params.

::: warning
Do not blindly restore state from untrusted sources. Validate the state structure before passing it to `restoreState()` to avoid crashes from malformed data.
:::
