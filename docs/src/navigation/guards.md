# Navigation Guards

Guards let you control navigation globally — for authentication, analytics, confirmation dialogs, or data preloading. They run before (or after) every navigation and can cancel, redirect, or simply observe.

## Guard Types

Vue Native navigation provides three guard hooks, executed in this order:

| Hook | Signature | Can Cancel? | Runs |
|------|-----------|-------------|------|
| `beforeEach` | `(to, from, next) => void` | Yes | Before every navigation |
| `beforeResolve` | `(to, from, next) => void` | Yes | After all `beforeEach` guards pass |
| `afterEach` | `(to, from) => void` | No | After navigation completes |

All guard registration methods return an **unsubscribe function**.

## beforeEach

Runs before every navigation. Call `next()` to proceed, `next(false)` to cancel, or `next('routeName')` to redirect.

```ts
import { createRouter } from '@thelacanians/vue-native-navigation'

const router = createRouter([
  { name: 'home', component: HomeView },
  { name: 'login', component: LoginView },
  { name: 'profile', component: ProfileView },
])

const unsubscribe = router.beforeEach((to, from, next) => {
  if (to.config.name === 'profile' && !isLoggedIn.value) {
    next('login') // redirect to login
  } else {
    next() // proceed normally
  }
})
```

### next() Behavior

| Call | Effect |
|------|--------|
| `next()` | Allow navigation to proceed |
| `next(false)` | Cancel navigation — stay on current screen |
| `next('routeName')` | Redirect to a different route |

If a guard returns a Promise and never calls `next()`, the guard auto-resolves when the Promise settles (equivalent to calling `next()`).

### Authentication Example

```vue
<script setup>
import { ref, onUnmounted } from 'vue'
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()
const isAuthenticated = ref(false)
const publicRoutes = ['home', 'login', 'register']

const unsubscribe = router.beforeEach((to, from, next) => {
  if (!publicRoutes.includes(to.config.name) && !isAuthenticated.value) {
    next('login')
  } else {
    next()
  }
})

onUnmounted(unsubscribe)
</script>
```

## beforeResolve

Same signature as `beforeEach`, but runs **after** all `beforeEach` guards have passed. Use it for final checks or data preloading that should only happen once you're sure the navigation won't be cancelled by an earlier guard.

```ts
router.beforeResolve(async (to, from, next) => {
  if (to.config.name === 'profile') {
    // Preload data now that auth guard has passed
    await prefetchUserProfile(to.params.userId)
  }
  next()
})
```

### Execution Order

For a navigation from `home` to `profile`:

1. All `beforeEach` guards run in registration order
2. If all pass → all `beforeResolve` guards run in registration order
3. If all pass → navigation happens (stack updates, screen renders)
4. All `afterEach` hooks run in registration order

If any `beforeEach` or `beforeResolve` guard calls `next(false)` or `next('redirect')`, the remaining guards in that phase are skipped and the navigation is cancelled or redirected.

## afterEach

Runs after navigation has completed. Cannot cancel or redirect — the navigation has already happened. Use it for analytics, logging, or side effects.

```ts
router.afterEach((to, from) => {
  analytics.track('screen_view', {
    screen: to.config.name,
    previousScreen: from.config.name,
    params: to.params,
  })
})
```

### Route Transition Logging

```ts
router.afterEach((to, from) => {
  console.log(`Navigated: ${from.config.name} → ${to.config.name}`)
})
```

## Guard Arguments

Both `to` and `from` are `RouteEntry` objects:

```ts
interface RouteEntry {
  config: {
    name: string
    component: Component
    options?: RouteOptions
  }
  params: Record<string, any>
  key: number
}
```

| Property | Description |
|----------|-------------|
| `config.name` | The route name string |
| `config.options` | Route display options (title, animation, etc.) |
| `params` | Parameters passed during navigation |
| `key` | Unique key for this stack entry |

## Unsubscribing

Every guard registration returns a function that removes the guard. Always clean up guards registered inside components:

```vue
<script setup>
import { onUnmounted } from 'vue'
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()

const unsub1 = router.beforeEach((to, from, next) => {
  // ...
  next()
})

const unsub2 = router.afterEach((to, from) => {
  // ...
})

onUnmounted(() => {
  unsub1()
  unsub2()
})
</script>
```

Guards registered at app initialization (outside a component) typically don't need cleanup since they live for the entire app lifecycle.

## Multiple Guards

You can register multiple guards of the same type. They execute in registration order:

```ts
// Guard 1: auth check
router.beforeEach((to, from, next) => {
  if (requiresAuth(to) && !isLoggedIn.value) {
    next('login')
  } else {
    next()
  }
})

// Guard 2: role check (only runs if guard 1 passed)
router.beforeEach((to, from, next) => {
  if (requiresAdmin(to) && !isAdmin.value) {
    next('home')
  } else {
    next()
  }
})

// Guard 3: analytics (runs after navigation)
router.afterEach((to, from) => {
  trackScreenView(to.config.name)
})
```

## Async Guards

Guards can be async. If a guard returns a Promise and doesn't call `next()`, the navigation system waits for the Promise to resolve and then auto-proceeds:

```ts
router.beforeEach(async (to, from, next) => {
  if (to.config.name === 'premium') {
    const hasAccess = await checkSubscription()
    if (!hasAccess) {
      next('upgrade')
      return
    }
  }
  next()
})
```

## Complete Example

A full auth flow with guards:

```ts
import { ref } from 'vue'
import { createApp } from '@thelacanians/vue-native-runtime'
import { createRouter } from '@thelacanians/vue-native-navigation'
import App from './App.vue'

const isLoggedIn = ref(false)
const userRole = ref<'user' | 'admin'>('user')

const router = createRouter([
  { name: 'home', component: HomeView },
  { name: 'login', component: LoginView },
  { name: 'dashboard', component: DashboardView },
  { name: 'admin', component: AdminView },
  { name: 'settings', component: SettingsView },
])

// Auth guard
router.beforeEach((to, from, next) => {
  const publicRoutes = ['home', 'login']
  if (!publicRoutes.includes(to.config.name) && !isLoggedIn.value) {
    next('login')
  } else {
    next()
  }
})

// Role guard
router.beforeEach((to, from, next) => {
  if (to.config.name === 'admin' && userRole.value !== 'admin') {
    next('home')
  } else {
    next()
  }
})

// Analytics
router.afterEach((to, from) => {
  analytics.track('screen_view', { screen: to.config.name })
})

createApp(App).use(router).start()
```

## See also

- [Stack navigation](./stack.md)
- [Screen lifecycle](./screen-lifecycle.md)
- [Navigation overview](./README.md)
