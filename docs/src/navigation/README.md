# Navigation

Vue Native provides stack-based navigation via `@thelacanians/vue-native-navigation`.

## Install

Navigation is included in the default project scaffold. To add it manually:

```bash
bun add @thelacanians/vue-native-navigation
```

## Quick start

```ts
// app/main.ts
import { createApp } from '@thelacanians/vue-native-runtime'
import { createRouter } from '@thelacanians/vue-native-navigation'
import App from './App.vue'
import HomeView from './views/HomeView.vue'
import DetailView from './views/DetailView.vue'

const router = createRouter([
  { name: 'home', component: HomeView },
  { name: 'detail', component: DetailView },
])

createApp(App).use(router).start()
```

```vue
<!-- App.vue -->
<template>
  <RouterView />
</template>
```

```vue
<!-- HomeView.vue -->
<script setup>
import { useRouter } from '@thelacanians/vue-native-navigation'
const router = useRouter()
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VButton
      :style="{ backgroundColor: '#007AFF', padding: 12, borderRadius: 8 }"
      :onPress="() => router.push('detail', { id: 1 })"
    >
      <VText :style="{ color: '#fff' }">Open Detail</VText>
    </VButton>
  </VView>
</template>
```

## Route options

Routes can specify display options:

```ts
const router = createRouter([
  { name: 'home', component: HomeView },
  {
    name: 'detail',
    component: DetailView,
    options: {
      title: 'Detail',
      headerShown: true,
      animation: 'push', // 'push' | 'modal' | 'fade' | 'none'
    },
  },
])
```

## Navigation guards

Guards let you control navigation globally -- for authentication, analytics, or confirmation dialogs.

### beforeEach

Runs before every navigation. Call `next()` to proceed, `next(false)` to cancel, or `next('routeName')` to redirect.

```ts
const unsubscribe = router.beforeEach((to, from, next) => {
  if (to.config.name === 'profile' && !isLoggedIn.value) {
    next('login')
  } else {
    next()
  }
})
```

### beforeResolve

Same as `beforeEach` but runs after all `beforeEach` guards have passed.

```ts
router.beforeResolve((to, from, next) => {
  next()
})
```

### afterEach

Runs after navigation completes. Cannot cancel navigation.

```ts
router.afterEach((to, from) => {
  analytics.track('screen_view', { screen: to.config.name })
})
```

All guard registration functions return an unsubscribe function.

## Screen lifecycle

Use `onScreenFocus` and `onScreenBlur` inside components rendered by `RouterView` to respond to screen visibility changes:

```vue
<script setup>
import { onScreenFocus, onScreenBlur } from '@thelacanians/vue-native-navigation'

onScreenFocus(() => {
  console.log('Screen is now visible')
  // Refresh data, start timers, etc.
})

onScreenBlur(() => {
  console.log('Screen is no longer visible')
  // Pause timers, save state, etc.
})
</script>
```

## Deep linking

Configure deep links by passing a `linking` config:

```ts
const router = createRouter({
  routes: [
    { name: 'home', component: HomeView },
    { name: 'profile', component: ProfileView },
    { name: 'post', component: PostView },
  ],
  linking: {
    prefixes: ['myapp://', 'https://myapp.com/'],
    config: {
      screens: {
        profile: 'user/:userId',
        post: 'post/:postId',
      },
    },
  },
})
```

When the app receives a URL like `myapp://user/42`, the router navigates to the `profile` screen with `{ userId: '42' }` as params.

The router handles both cold-start URLs (via `Linking.getInitialURL()`) and URLs received while the app is running.

## See also

- [Stack navigation](./stack.md)
- [Passing params](./params.md)
