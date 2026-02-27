# VTabBar

A tab bar component for switching between screens. Renders a row of tappable tabs at the bottom of the screen. Supports `v-model` for two-way binding of the active tab.

## Usage

```vue
<VTabBar
  v-model="activeTab"
  :tabs="[
    { name: 'home', label: 'Home', icon: 'house' },
    { name: 'settings', label: 'Settings', icon: 'gear' },
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
  icon?: string     // Icon name (platform-specific)
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
        { name: 'home', label: 'Home', icon: 'house' },
        { name: 'search', label: 'Search', icon: 'magnifyingglass' },
        { name: 'profile', label: 'Profile', icon: 'person' },
      ]"
      activeColor="#007AFF"
      inactiveColor="#8E8E93"
      backgroundColor="#FFFFFF"
    />
  </VView>
</template>
```

## With Tab Navigator

`VTabBar` is most commonly used with `createTabNavigator`, which handles screen switching automatically:

```vue
<script setup>
import { createTabNavigator, VTabBar, RouterView } from '@thelacanians/vue-native-navigation'
import HomeScreen from './pages/Home.vue'
import SettingsScreen from './pages/Settings.vue'

const tabs = createTabNavigator({
  tabs: [
    { name: 'home', component: HomeScreen, label: 'Home', icon: 'house' },
    { name: 'settings', component: SettingsScreen, label: 'Settings', icon: 'gear' },
  ],
})
</script>

<template>
  <VView :style="{ flex: 1 }">
    <RouterView />
    <VTabBar
      v-model="tabs.activeTab.value"
      :tabs="tabs.tabItems"
    />
  </VView>
</template>
```

## Notes

- `VTabBar` is exported from `@thelacanians/vue-native-navigation`, not the runtime package.
- The tab bar renders at the bottom of the screen. It does not automatically account for the safe area — wrap it in a `VSafeArea` or add bottom padding on devices with home indicators.
- Icon names are platform-specific: SF Symbols on iOS, Material Icons on Android.
