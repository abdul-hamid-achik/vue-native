# Tab Navigation

Vue Native provides tab-based navigation via `createTabNavigator()` from `@thelacanians/vue-native-navigation`. Tabs render a bottom tab bar with configurable colors and support lazy mounting for performance.

## Quick start

```ts
import { createTabNavigator } from '@thelacanians/vue-native-navigation'
import HomeView from './views/HomeView.vue'
import SearchView from './views/SearchView.vue'
import ProfileView from './views/ProfileView.vue'

const { TabNavigator, activeTab } = createTabNavigator()
```

```vue
<!-- App.vue -->
<script setup>
import { createTabNavigator } from '@thelacanians/vue-native-navigation'
import HomeView from './views/HomeView.vue'
import SearchView from './views/SearchView.vue'
import ProfileView from './views/ProfileView.vue'

const { TabNavigator, activeTab } = createTabNavigator()
</script>

<template>
  <TabNavigator
    :screens="[
      { name: 'home', label: 'Home', icon: '🏠', component: HomeView },
      { name: 'search', label: 'Search', icon: '🔍', component: SearchView },
      { name: 'profile', label: 'Profile', icon: '👤', component: ProfileView },
    ]"
    initialTab="home"
  />
</template>
```

## TabNavigator props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `screens` | `TabScreenConfig[]` | `[]` | Ordered screen descriptors. May be replaced by declarative `TabScreen` children |
| `initialTab` | `string` | `''` | Which tab is shown first. Defaults to the first screen when empty |
| `activeColor` | `string` | `'#007AFF'` | Color applied to the active tab icon and label |
| `inactiveColor` | `string` | `'#8E8E93'` | Color applied to inactive tab icons and labels |
| `tabBarBackgroundColor` | `string` | `'#F9F9F9'` | Background color of the tab bar |

## TabScreenConfig

```ts
interface TabScreenConfig {
  /** Unique identifier for the tab */
  name: string
  /** Display label shown below the icon in the tab bar */
  label?: string
  /** Text glyph or emoji rendered in the tab bar */
  icon?: string
  /** Vue component rendered as the tab content */
  component: Component
  /** When true, content is not mounted until the tab is first visited */
  lazy?: boolean
}
```

## Declarative screen configuration

For static screen lists, use the returned `TabScreen` component instead of the `screens` prop:

```vue
<script setup>
import { createTabNavigator } from '@thelacanians/vue-native-navigation'
import HomeView from './views/HomeView.vue'
import SearchView from './views/SearchView.vue'

const { TabNavigator, TabScreen } = createTabNavigator()
</script>

<template>
  <TabNavigator initialTab="home">
    <TabScreen name="home" label="Home" icon="🏠" :component="HomeView" />
    <TabScreen name="search" label="Search" icon="🔍" :component="SearchView" lazy />
  </TabNavigator>
</template>
```

When both forms are supplied, a non-empty `screens` prop takes precedence over declarative children.

## Lazy tabs

By default, all tab screens are mounted immediately — only the active tab is visible (rendered at full size) while inactive tabs are hidden (rendered at size 0). This keeps their state alive when switching between tabs.

Set `lazy: true` on a screen to defer mounting until the user first visits that tab. Once mounted, the screen stays alive:

```vue
<script setup>
import { createTabNavigator } from '@thelacanians/vue-native-navigation'
import HomeView from './views/HomeView.vue'
import SearchView from './views/SearchView.vue'
import SettingsView from './views/SettingsView.vue'

const { TabNavigator } = createTabNavigator()

const screens = [
  { name: 'home', label: 'Home', icon: '🏠', component: HomeView },
  { name: 'search', label: 'Search', icon: '🔍', component: SearchView, lazy: true },
  { name: 'settings', label: 'Settings', icon: '⚙️', component: SettingsView, lazy: true },
]
</script>

<template>
  <TabNavigator
    :screens="screens"
    initialTab="home"
    activeColor="#FF6B35"
    inactiveColor="#999"
    tabBarBackgroundColor="#FFFFFF"
  />
</template>
```

In this example, `SearchView` and `SettingsView` are not mounted until the user taps their respective tabs for the first time.

## Programmatic tab switching

`createTabNavigator()` returns a reactive `activeTab` ref that tracks the currently visible tab. You can read it to respond to tab changes or write to it to switch tabs programmatically:

```vue
<script setup>
import { watch } from 'vue'
import { createTabNavigator } from '@thelacanians/vue-native-navigation'
import HomeView from './views/HomeView.vue'
import NotificationsView from './views/NotificationsView.vue'
import ProfileView from './views/ProfileView.vue'

const { TabNavigator, activeTab } = createTabNavigator()

const screens = [
  { name: 'home', label: 'Home', icon: '🏠', component: HomeView },
  { name: 'notifications', label: 'Alerts', icon: '🔔', component: NotificationsView },
  { name: 'profile', label: 'Profile', icon: '👤', component: ProfileView },
]

// React to tab changes
watch(activeTab, (tab) => {
  console.log('Switched to tab:', tab)
})

// Switch tabs from code (e.g. after a deep link or action)
function goToProfile() {
  activeTab.value = 'profile'
}
</script>

<template>
  <TabNavigator :screens="screens" initialTab="home" />
</template>
```

You can also pass the `activeTab` ref into child components via `provide`/`inject` or props to allow any descendant to trigger tab switches.

## See also

- [Stack navigation](./stack.md)
- [Drawer navigation](./drawer.md)
- [Navigation overview](./README.md)
