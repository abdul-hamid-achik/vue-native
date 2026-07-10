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

## Notes

- `@thelacanians/vue-native-navigation` exports the navigator-integrated tab bar shown on this page.
- `@thelacanians/vue-native-runtime` also exports a lower-level `VTabBar` for standalone layouts. It accepts either `id` or `name` identifiers, supports badges and top/bottom positioning, and emits both `change` and `update:modelValue`.
- The tab bar renders at the bottom of the screen. It does not automatically account for the safe area — wrap it in a `VSafeArea` or add bottom padding on devices with home indicators.
- `icon` is rendered as text. Use an emoji, glyph, or a custom tab-bar component when you need an icon library; symbol names are not resolved automatically.
