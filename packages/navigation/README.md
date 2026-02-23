# @thelacanians/vue-native-navigation

Stack navigation for Vue Native apps. Inspired by Vue Router with a native-first API.

## Install

```bash
npm install @thelacanians/vue-native-navigation
# or
bun add @thelacanians/vue-native-navigation
```

## Usage

### Define routes

```ts
// app/main.ts
import { createApp } from 'vue'
import { createRouter } from '@thelacanians/vue-native-navigation'
import App from './App.vue'
import Home from './pages/Home.vue'
import Settings from './pages/Settings.vue'

const router = createRouter([
  { name: 'Home', component: Home },
  { name: 'Settings', component: Settings },
])

const app = createApp(App)
app.use(router)
app.start()
```

### Add RouterView

```vue
<!-- App.vue -->
<template>
  <VSafeArea :style="{ flex: 1 }">
    <RouterView />
  </VSafeArea>
</template>

<script setup lang="ts">
import { RouterView } from '@thelacanians/vue-native-navigation'
</script>
```

### Navigate

```vue
<script setup lang="ts">
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()

function goToSettings() {
  router.push('Settings')
}

function goBack() {
  router.back()
}
</script>
```

### Route params

```ts
// Pass params
router.push('UserProfile', { userId: '123' })

// Read params in the target screen
import { useRoute } from '@thelacanians/vue-native-navigation'

const route = useRoute()
const userId = route.value.params.userId
```

## API

### `createRouter(routes)`

Creates a router instance from an array of route configs.

```ts
interface RouteConfig {
  name: string
  component: Component
  options?: {
    title?: string
    headerShown?: boolean
    animation?: 'push' | 'modal' | 'fade' | 'none'
  }
}
```

### `useRouter()`

Returns the router instance with navigation methods:

- `push(name, params?)` - Navigate to a route
- `back()` - Go back one screen
- `replace(name, params?)` - Replace current screen
- `reset(name, params?)` - Reset stack to a single screen

### `useRoute()`

Returns a `ComputedRef` with the current route info:

```ts
interface RouteLocation {
  name: string
  params: Record<string, any>
  key: string
}
```

### `<RouterView />`

Renders the current route's component with native transition animations.

## License

MIT
