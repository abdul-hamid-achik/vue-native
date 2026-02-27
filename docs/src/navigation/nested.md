# Nested Navigators

You can nest navigators to build complex navigation patterns — for example, a tab navigator where each tab has its own stack, or a drawer that wraps a stack.

## Tab + Stack

A common pattern is tabs at the root, with each tab owning an independent stack:

```ts
import { createRouter, createTabNavigator } from '@thelacanians/vue-native-navigation'

const HomeStack = createRouter({
  routes: [
    { name: 'home', component: HomeScreen },
    { name: 'detail', component: DetailScreen },
  ],
})

const SettingsStack = createRouter({
  routes: [
    { name: 'settings', component: SettingsScreen },
    { name: 'profile', component: ProfileScreen },
  ],
})

const tabs = createTabNavigator({
  tabs: [
    { name: 'homeTab', router: HomeStack, label: 'Home', icon: 'house' },
    { name: 'settingsTab', router: SettingsStack, label: 'Settings', icon: 'gear' },
  ],
})
```

Each tab's stack is independent — pushing a screen in the Home tab does not affect the Settings tab's stack.

## Drawer + Stack

Wrap a stack navigator inside a drawer:

```ts
import { createRouter, createDrawerNavigator } from '@thelacanians/vue-native-navigation'

const mainStack = createRouter({
  routes: [
    { name: 'home', component: HomeScreen },
    { name: 'detail', component: DetailScreen },
  ],
})

const drawer = createDrawerNavigator({
  router: mainStack,
  items: [
    { name: 'home', label: 'Home', icon: 'house' },
    { name: 'about', label: 'About', component: AboutScreen },
  ],
})
```

## useParentRouter

When inside a nested navigator, use `useParentRouter()` to access the parent router:

```vue
<script setup>
import { useRouter, useParentRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()          // Current (child) router
const parent = useParentRouter()    // Parent router (e.g., tab navigator)
</script>
```

This is useful when a child screen needs to switch tabs or open the drawer:

```ts
// Switch to the settings tab from within the home stack
parent.navigate('settingsTab')
```

## Independent Stacks

Each nested router maintains its own stack independently. Navigating within one stack does not affect sibling stacks:

```vue
<script setup>
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()

// This only affects the current tab's stack
router.push('detail', { id: 42 })
</script>
```

When switching tabs, the previous tab's stack is preserved. Going back to a tab shows the last screen the user was on.

## Deep Linking with Nested Navigators

Deep links can target screens inside nested navigators using path segments:

```ts
const HomeStack = createRouter({
  routes: [
    { name: 'home', component: HomeScreen },
    { name: 'detail', component: DetailScreen },
  ],
  linking: {
    prefixes: ['myapp://'],
    config: {
      screens: {
        detail: 'items/:id',
      },
    },
  },
})
```

When the app receives a deep link like `myapp://items/42`, the router will:

1. Switch to the tab containing `HomeStack`
2. Push the `detail` screen with `{ id: '42' }` params

## Example: Full App with Nested Navigation

```vue
<!-- App.vue -->
<script setup>
import { createRouter, createTabNavigator, RouterView } from '@thelacanians/vue-native-navigation'
import HomeScreen from './pages/Home.vue'
import DetailScreen from './pages/Detail.vue'
import SettingsScreen from './pages/Settings.vue'

const homeStack = createRouter({
  routes: [
    { name: 'home', component: HomeScreen },
    { name: 'detail', component: DetailScreen },
  ],
})

const settingsStack = createRouter({
  routes: [
    { name: 'settings', component: SettingsScreen },
  ],
})

const app = createTabNavigator({
  tabs: [
    { name: 'homeTab', router: homeStack, label: 'Home', icon: 'house' },
    { name: 'settingsTab', router: settingsStack, label: 'Settings', icon: 'gear' },
  ],
})
</script>

<template>
  <RouterView />
</template>
```

::: tip
Keep nesting shallow — one or two levels deep is typical. Deeply nested navigators can make the navigation structure hard to reason about and debug.
:::
