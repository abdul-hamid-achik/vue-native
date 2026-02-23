# Navigation

Vue Native includes stack-based navigation via `@vue-native/navigation`.

## Setup

```ts
// app/main.ts
import { createApp } from '@vue-native/runtime'
import { createRouter } from '@vue-native/navigation'
import App from './App.vue'
import HomeView from './views/HomeView.vue'
import DetailView from './views/DetailView.vue'

const { router } = createRouter([
  { name: 'home', component: HomeView },
  { name: 'detail', component: DetailView },
])

createApp(App).use(router).mount('#app')
```

## Root component

```vue
<!-- App.vue -->
<template>
  <RouterView />
</template>
```

## Navigating

```vue
<!-- HomeView.vue -->
<script setup>
import { useRouter } from '@vue-native/navigation'
const router = useRouter()
</script>

<template>
  <VView style="flex: 1">
    <VButton @press="router.push('detail', { id: 42 })">
      <VText>Go to Detail</VText>
    </VButton>
  </VView>
</template>
```

## Reading params

```vue
<!-- DetailView.vue -->
<script setup>
import { useRoute } from '@vue-native/navigation'
const route = useRoute()
// route.params.id === 42
</script>
```

## API

### `createRouter(routes)`

Creates a router instance. Call once at app startup.

```ts
const { router } = createRouter([
  { name: 'home', component: HomeView },
  { name: 'detail', component: DetailView },
])
```

### `useRouter()`

Returns the router instance.

| Method | Description |
|--------|-------------|
| `router.push(name, params?)` | Navigate to a screen |
| `router.pop()` | Go back to the previous screen |
| `router.replace(name, params?)` | Replace current screen (no back entry) |
| `router.reset(name, params?)` | Reset the stack to a single screen |

### `useRoute()`

Returns the current route.

| Property | Type | Description |
|----------|------|-------------|
| `route.name` | `string` | Current screen name |
| `route.params` | `Record<string, any>` | Navigation params |
