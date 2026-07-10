# Navigator Composition

Tab and drawer navigators can render other navigator components as screens. This supports layouts such as a drawer whose main screen contains tabs, or a tab that hosts the application's one stack router.

::: warning Independent nested stacks
The current public API does **not** provide a separate stack-router context for every tab or drawer screen. `createTabNavigator()` and `createDrawerNavigator()` take no arguments and do not accept `{ tabs }`, `{ items }`, or `{ router }` options. Configure the returned navigator through its `screens` prop or declarative `TabScreen`/`DrawerScreen` children.
:::

## Drawer containing tabs

Create each navigator once and export the returned component and state. Importing the same instance is important: calling a factory again creates a different navigator state.

```ts
// navigation/tabs.ts
import { createTabNavigator } from '@thelacanians/vue-native-navigation'

export const { TabNavigator, activeTab } = createTabNavigator()
```

```vue
<!-- TabbedHome.vue -->
<script setup>
import { TabNavigator } from './navigation/tabs'
import FeedScreen from './pages/Feed.vue'
import ProfileScreen from './pages/Profile.vue'

const screens = [
  { name: 'feed', label: 'Feed', icon: '🏠', component: FeedScreen },
  { name: 'profile', label: 'Profile', icon: '👤', component: ProfileScreen },
]
</script>

<template>
  <TabNavigator :screens="screens" initialTab="feed" />
</template>
```

```ts
// navigation/drawer.ts
import { createDrawerNavigator } from '@thelacanians/vue-native-navigation'

export const { DrawerNavigator, useDrawer, activeScreen } = createDrawerNavigator()
```

```vue
<!-- App.vue -->
<script setup>
import { DrawerNavigator } from './navigation/drawer'
import TabbedHome from './TabbedHome.vue'
import AboutScreen from './pages/About.vue'

const screens = [
  { name: 'main', label: 'Home', icon: '🏠', component: TabbedHome },
  { name: 'about', label: 'About', icon: 'ℹ️', component: AboutScreen },
]
</script>

<template>
  <DrawerNavigator :screens="screens" initialScreen="main" />
</template>
```

This is component composition, not a parent/child stack relationship. The drawer tracks `activeScreen`; the tab navigator independently tracks `activeTab`.

## Hosting one stack inside a tab

A `RouterView` resolves the router installed on the Vue application. You can render that one root stack inside a tab component.

```ts
// navigation/router.ts
import { createRouter } from '@thelacanians/vue-native-navigation'
import HomeScreen from '../pages/Home.vue'
import DetailScreen from '../pages/Detail.vue'

export const router = createRouter({
  routes: [
    { name: 'home', component: HomeScreen },
    { name: 'detail', component: DetailScreen },
  ],
  linking: {
    prefixes: ['myapp://'],
    config: {
      screens: {
        home: '',
        detail: 'items/:id',
      },
    },
  },
})
```

```ts
// main.ts
import { createApp } from '@thelacanians/vue-native-runtime'
import App from './App.vue'
import { router } from './navigation/router'

createApp(App).use(router).start()
```

```vue
<!-- StackHost.vue -->
<script setup>
import { RouterView } from '@thelacanians/vue-native-navigation'
</script>

<template>
  <RouterView />
</template>
```

```vue
<!-- App.vue -->
<script setup>
import { createTabNavigator } from '@thelacanians/vue-native-navigation'
import StackHost from './StackHost.vue'
import SettingsScreen from './pages/Settings.vue'

const { TabNavigator, activeTab } = createTabNavigator()

const screens = [
  { name: 'home', label: 'Home', icon: '🏠', component: StackHost },
  { name: 'settings', label: 'Settings', icon: '⚙️', component: SettingsScreen },
]

function showHomeStack() {
  activeTab.value = 'home'
}
</script>

<template>
  <TabNavigator :screens="screens" initialTab="home" />
</template>
```

The stack remains mounted when its tab is hidden, so its navigation history is preserved. Adding another `RouterView` to another tab would resolve the same root router; it would **not** create an independent sibling stack.

## Switching containers programmatically

Use the state returned by the navigator factory:

```ts
import { activeTab } from './navigation/tabs'
import { activeScreen, useDrawer } from './navigation/drawer'

activeTab.value = 'profile'
activeScreen.value = 'about'

const { openDrawer, closeDrawer } = useDrawer()
openDrawer()
closeDrawer()
```

Do not use `router.navigate()` to switch a tab or drawer item: those names are not stack routes.

## `useParentRouter()`

`useParentRouter()` returns `router.parent` when the current router has a parent, otherwise it returns the current router. Tab and drawer navigators do not currently create or provide child `RouterInstance` objects, so this composable does not switch tabs or open a drawer in the supported component API.

Use `activeTab`, `activeScreen`, or the drawer state returned by the corresponding factory for those actions.

## Deep links

The `linking` option belongs to `createRouter()`. A root stack hosted inside a tab can handle its configured links, but the router does not automatically select the containing tab or drawer item.

When your application handles a URL explicitly, select the container first and then pass the URL to the root router:

```ts
import { router } from './navigation/router'
import { activeTab } from './navigation/tabs'

export function openAppURL(url: string): boolean {
  activeTab.value = 'home'
  return router.handleURL(url)
}
```

Use this helper for URLs entering through app-owned code or tests. Do not also send the same URL through the native automatic listener, or the stack may navigate twice. If you rely on the router's automatic native URL listener, keep the stack's containing tab selected by default or add equivalent application-level selection logic.

## Current limitation

Independent stack history per tab requires a public nested-router provider that scopes `useRouter()` and `RouterView` to a child router. That provider is not part of the current public API. Until it is, use one root stack plus tab/drawer component state, or keep each tab as a stateful screen component.

## See also

- [Stack navigation](./stack.md)
- [Tab navigation](./tabs.md)
- [Drawer navigation](./drawer.md)
