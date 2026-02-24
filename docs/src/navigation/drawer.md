# Drawer Navigation

Vue Native provides drawer-based navigation via `createDrawerNavigator()` from `@thelacanians/vue-native-navigation`. The drawer slides in from the left or right and can display a default screen list or fully custom content.

## Quick start

```ts
import { createDrawerNavigator } from '@thelacanians/vue-native-navigation'
import HomeView from './views/HomeView.vue'
import SettingsView from './views/SettingsView.vue'
import AboutView from './views/AboutView.vue'

const { DrawerNavigator, DrawerScreen, useDrawer, activeScreen } = createDrawerNavigator()
```

```vue
<!-- App.vue -->
<script setup>
import { createDrawerNavigator } from '@thelacanians/vue-native-navigation'
import HomeView from './views/HomeView.vue'
import SettingsView from './views/SettingsView.vue'
import AboutView from './views/AboutView.vue'

const { DrawerNavigator } = createDrawerNavigator()
</script>

<template>
  <DrawerNavigator
    :screens="[
      { name: 'home', label: 'Home', icon: 'house', component: HomeView },
      { name: 'settings', label: 'Settings', icon: 'gear', component: SettingsView },
      { name: 'about', label: 'About', icon: 'info.circle', component: AboutView },
    ]"
    initialScreen="home"
  />
</template>
```

## DrawerNavigator props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `screens` | `DrawerScreenConfig[]` | — (required) | Ordered list of drawer screen descriptors |
| `drawerContent` | `Component` | `undefined` | Custom component for the drawer panel. Receives `{ screens, activeScreen, onSelect }` as props |
| `drawerWidth` | `number` | `280` | Width of the drawer panel in points |
| `drawerPosition` | `'left' \| 'right'` | `'left'` | Which edge the drawer slides in from |
| `initialScreen` | `string` | `''` | Which screen is shown first. Defaults to the first screen when empty |
| `drawerBackgroundColor` | `string` | `'#FFFFFF'` | Background color of the drawer panel |
| `overlayColor` | `string` | `'rgba(0,0,0,0.4)'` | Color of the semi-transparent overlay behind the drawer |

## DrawerScreenConfig

```ts
interface DrawerScreenConfig {
  /** Unique identifier for the screen */
  name: string
  /** Display label shown in the drawer menu */
  label?: string
  /** Icon name rendered alongside the label */
  icon?: string
  /** Vue component rendered as the screen content */
  component: Component
}
```

`DrawerScreen` is a declarative config component that renders nothing on its own. Its props are read by the parent `DrawerNavigator`:

```vue
<template>
  <DrawerNavigator>
    <DrawerScreen name="home" label="Home" icon="house" :component="HomeView" />
    <DrawerScreen name="settings" label="Settings" icon="gear" :component="SettingsView" />
  </DrawerNavigator>
</template>
```

## useDrawer()

The `useDrawer` composable provides programmatic control over the drawer state:

```ts
const { isOpen, openDrawer, closeDrawer, toggleDrawer } = useDrawer()
```

| Property | Type | Description |
|----------|------|-------------|
| `isOpen` | `Ref<boolean>` | Reactive ref indicating whether the drawer is currently open |
| `openDrawer` | `() => void` | Opens the drawer |
| `closeDrawer` | `() => void` | Closes the drawer |
| `toggleDrawer` | `() => void` | Toggles the drawer open or closed |

### Using useDrawer in a screen

```vue
<!-- HomeView.vue -->
<script setup>
import { createDrawerNavigator } from '@thelacanians/vue-native-navigation'

const { useDrawer } = createDrawerNavigator()
const { openDrawer } = useDrawer()
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VButton
      :style="{ backgroundColor: '#007AFF', padding: 12, borderRadius: 8 }"
      :onPress="openDrawer"
    >
      <VText :style="{ color: '#fff' }">Open Menu</VText>
    </VButton>
  </VView>
</template>
```

## Custom drawer content

Pass a `drawerContent` component to replace the default drawer menu. Your component receives three props:

- `screens` — the `DrawerScreenConfig[]` array
- `activeScreen` — the name of the currently active screen
- `onSelect` — a callback `(screenName: string) => void` that navigates to a screen and closes the drawer

```vue
<!-- CustomDrawer.vue -->
<script setup>
defineProps<{
  screens: { name: string; label?: string; icon?: string }[]
  activeScreen: string
  onSelect: (name: string) => void
}>()
</script>

<template>
  <VView :style="{ flex: 1, paddingTop: 60, paddingHorizontal: 20 }">
    <VText :style="{ fontSize: 24, fontWeight: 'bold', marginBottom: 30 }">
      My App
    </VText>
    <VView v-for="screen in screens" :key="screen.name">
      <VButton
        :style="{
          padding: 16,
          marginBottom: 4,
          borderRadius: 12,
          backgroundColor: activeScreen === screen.name ? '#E8F0FE' : 'transparent',
        }"
        :onPress="() => onSelect(screen.name)"
      >
        <VText
          :style="{
            fontSize: 16,
            color: activeScreen === screen.name ? '#1A73E8' : '#333',
            fontWeight: activeScreen === screen.name ? '600' : '400',
          }"
        >
          {{ screen.label || screen.name }}
        </VText>
      </VButton>
    </VView>
  </VView>
</template>
```

```vue
<!-- App.vue -->
<script setup>
import { createDrawerNavigator } from '@thelacanians/vue-native-navigation'
import CustomDrawer from './components/CustomDrawer.vue'
import HomeView from './views/HomeView.vue'
import SettingsView from './views/SettingsView.vue'

const { DrawerNavigator } = createDrawerNavigator()

const screens = [
  { name: 'home', label: 'Home', icon: 'house', component: HomeView },
  { name: 'settings', label: 'Settings', icon: 'gear', component: SettingsView },
]
</script>

<template>
  <DrawerNavigator
    :screens="screens"
    :drawerContent="CustomDrawer"
    :drawerWidth="300"
    drawerBackgroundColor="#FAFAFA"
  />
</template>
```

## Right-side drawer

Set `drawerPosition` to `'right'` to make the drawer slide in from the right edge:

```vue
<script setup>
import { createDrawerNavigator } from '@thelacanians/vue-native-navigation'
import HomeView from './views/HomeView.vue'
import NotificationsView from './views/NotificationsView.vue'

const { DrawerNavigator, useDrawer } = createDrawerNavigator()
const { toggleDrawer } = useDrawer()

const screens = [
  { name: 'home', label: 'Home', icon: 'house', component: HomeView },
  { name: 'notifications', label: 'Notifications', icon: 'bell', component: NotificationsView },
]
</script>

<template>
  <DrawerNavigator
    :screens="screens"
    drawerPosition="right"
    :drawerWidth="320"
    overlayColor="rgba(0,0,0,0.5)"
  />
</template>
```

## Reactive active screen

`createDrawerNavigator()` returns a reactive `activeScreen` ref that tracks the currently visible screen. You can watch it or write to it to switch screens programmatically:

```vue
<script setup>
import { watch } from 'vue'
import { createDrawerNavigator } from '@thelacanians/vue-native-navigation'
import HomeView from './views/HomeView.vue'
import ProfileView from './views/ProfileView.vue'

const { DrawerNavigator, activeScreen } = createDrawerNavigator()

const screens = [
  { name: 'home', label: 'Home', component: HomeView },
  { name: 'profile', label: 'Profile', component: ProfileView },
]

watch(activeScreen, (screen) => {
  console.log('Active screen:', screen)
})

function navigateToProfile() {
  activeScreen.value = 'profile'
}
</script>

<template>
  <DrawerNavigator :screens="screens" />
</template>
```

## See also

- [Stack navigation](./stack.md)
- [Tab navigation](./tabs.md)
- [Navigation overview](./README.md)
