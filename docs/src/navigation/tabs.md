# Tab Navigation

Vue Native provides tab-based navigation via `createTabNavigator()` from `@thelacanians/vue-native-navigation`. Tabs render a bottom tab bar with configurable colors and support lazy mounting for performance.

## Quick start

```ts
import { createTabNavigator } from '@thelacanians/vue-native-navigation'
import HomeView from './views/HomeView.vue'
import SearchView from './views/SearchView.vue'
import ProfileView from './views/ProfileView.vue'

const { TabNavigator, TabScreen, activeTab } = createTabNavigator()
```

```vue
<!-- App.vue -->
<script setup>
import { createTabNavigator } from '@thelacanians/vue-native-navigation'
import HomeView from './views/HomeView.vue'
import SearchView from './views/SearchView.vue'
import ProfileView from './views/ProfileView.vue'

const { TabNavigator, TabScreen, activeTab } = createTabNavigator()
</script>

<template>
  <TabNavigator
    :screens="[
      { name: 'home', label: 'Home', icon: 'house', component: HomeView },
      { name: 'search', label: 'Search', icon: 'magnifyingglass', component: SearchView },
      { name: 'profile', label: 'Profile', icon: 'person', component: ProfileView },
    ]"
    initialTab="home"
  />
</template>
```

## TabNavigator props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `screens` | `TabScreenConfig[]` | — (required) | Ordered list of tab screen descriptors |
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
  /** Icon name rendered in the tab bar */
  icon?: string
  /** Vue component rendered as the tab content */
  component: Component
  /** When true, content is not mounted until the tab is first visited */
  lazy?: boolean
}
```

## Declarative screen configuration

`TabScreen` is a declarative config component that renders nothing on its own. Its props are read by the parent `TabNavigator`:

```vue
<template>
  <TabNavigator>
    <TabScreen name="home" label="Home" icon="house" :component="HomeView" />
    <TabScreen name="search" label="Search" icon="magnifyingglass" :component="SearchView" />
    <TabScreen name="profile" label="Profile" icon="person" :component="ProfileView" />
  </TabNavigator>
</template>
```

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
  { name: 'home', label: 'Home', icon: 'house', component: HomeView },
  { name: 'search', label: 'Search', icon: 'magnifyingglass', component: SearchView, lazy: true },
  { name: 'settings', label: 'Settings', icon: 'gear', component: SettingsView, lazy: true },
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
  { name: 'home', label: 'Home', icon: 'house', component: HomeView },
  { name: 'notifications', label: 'Alerts', icon: 'bell', component: NotificationsView },
  { name: 'profile', label: 'Profile', icon: 'person', component: ProfileView },
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
