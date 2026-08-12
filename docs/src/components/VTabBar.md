# VTabBar

A tab bar component for switching between screens. Renders a row of tappable tabs at the bottom of the screen. Supports `v-model` for two-way binding of the active tab.

## Usage

```vue
<VTabBar
  v-model="activeTab"
  :tabs="[
    { name: 'home', label: 'Home', icon: '🏠' },
    { name: 'settings', label: 'Settings', icon: '⚙️' },
  ]"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `tabs` | `TabBarItem[]` | **required** | Array of tab definitions |
| `modelValue` | `string` | `''` | The name of the active tab (use with `v-model`) |
| `activeColor` | `string` | `'#007AFF'` | Color of the active tab icon and label |
| `inactiveColor` | `string` | `'#8E8E93'` | Color of inactive tab icons and labels |
| `backgroundColor` | `string` | `'#F9F9F9'` | Background color of the tab bar |

### TabBarItem

```ts
interface TabBarItem {
  name: string      // Unique identifier for the tab
  label?: string    // Display label below the icon
  icon?: string     // Text glyph or emoji
}
```

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@update:modelValue` | `string` | Emitted when the active tab changes (used by `v-model`) |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const activeTab = ref('home')
</script>

<template>
  <VView :style="{ flex: 1 }">
    <VView :style="{ flex: 1, padding: 16 }">
      <VText v-if="activeTab === 'home'">Home Screen</VText>
      <VText v-if="activeTab === 'search'">Search Screen</VText>
      <VText v-if="activeTab === 'profile'">Profile Screen</VText>
    </VView>

    <VTabBar
      v-model="activeTab"
      :tabs="[
        { name: 'home', label: 'Home', icon: '🏠' },
        { name: 'search', label: 'Search', icon: '🔍' },
        { name: 'profile', label: 'Profile', icon: '👤' },
      ]"
      activeColor="#007AFF"
      inactiveColor="#8E8E93"
      backgroundColor="#FFFFFF"
    />
  </VView>
</template>
```

## With Tab Navigator

`VTabBar` is most commonly used with `createTabNavigator`, which handles screen switching automatically. Import that navigator-integrated export from the navigation package:

```vue
<script setup>
import { createTabNavigator } from '@thelacanians/vue-native-navigation'
import HomeScreen from './pages/Home.vue'
import SettingsScreen from './pages/Settings.vue'

const { TabNavigator } = createTabNavigator()
const screens = [
  { name: 'home', component: HomeScreen, label: 'Home', icon: '🏠' },
  { name: 'settings', component: SettingsScreen, label: 'Settings', icon: '⚙️' },
]
</script>

<template>
  <TabNavigator :screens="screens" initialTab="home" />
</template>
```

## Low-Level Runtime Variant

`@thelacanians/vue-native-runtime` also exports a `VTabBar` -- a different,
lower-level component than the navigator-integrated one documented above.
Both share the name `VTabBar`, so import from the package that matches the
variant you want:

```ts
// Navigator-integrated (documented above)
import { VTabBar } from '@thelacanians/vue-native-navigation'

// Low-level, standalone runtime variant
import { VTabBar } from '@thelacanians/vue-native-runtime'
```

The runtime variant self-positions as an absolutely-positioned bar at the top
or bottom edge of its parent (height `60`), supports per-tab badges, and
accepts either `id` or `name` as the tab identifier.

```vue
<VTabBar
  :tabs="[
    { id: 'home', label: 'Home', icon: '🏠' },
    { id: 'inbox', label: 'Inbox', icon: '📥', badge: 3 },
  ]"
  v-model="activeTab"
  position="bottom"
  @change="onTabChange"
/>
```

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `tabs` | `TabConfig[]` | **required** | Array of tab configurations |
| `activeTab` | `string` | — | Currently active tab id/name. Updated externally (e.g. by a router); prefer `modelValue` for local `v-model` state. |
| `modelValue` | `string` | — | Currently active tab id/name for `v-model`. Takes precedence over `activeTab` as the initial value. |
| `position` | `'top' \| 'bottom'` | `'bottom'` | Which edge of the parent the bar is pinned to |
| `activeColor` | `string` | `'#007AFF'` | Color of the active tab's icon, label, and badge text |
| `inactiveColor` | `string` | `'#8E8E93'` | Color of inactive tab icons and labels |
| `backgroundColor` | `string` | `'#fff'` | Background color of the tab bar |

### TabConfig

```ts
type TabConfig = {
  label: string
  icon?: string           // Text glyph or emoji
  badge?: number | string // Shown as a small red badge in the top-right corner of the tab
} & (
  | { id: string, name?: string }
  | { id?: string, name: string }
) // exactly one of id / name identifies the tab
```

### Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@change` | `string` (tab id/name) | Emitted when the user taps a different tab |
| `@update:modelValue` | `string` (tab id/name) | Emitted alongside `@change`. Used by `v-model` |

## Notes

- `@thelacanians/vue-native-navigation` exports the navigator-integrated tab bar shown at the top of this page; `@thelacanians/vue-native-runtime` exports the lower-level standalone variant documented above -- see [Low-Level Runtime Variant](#low-level-runtime-variant).
- The tab bar renders at the bottom of the screen (or top, for the runtime variant with `position="top"`). It does not automatically account for the safe area — wrap it in a `VSafeArea` or add bottom padding on devices with home indicators.
- `icon` is rendered as text. Use an emoji, glyph, or a custom tab-bar component when you need an icon library; symbol names are not resolved automatically.
