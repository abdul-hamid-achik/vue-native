<script setup lang="ts">
import {
  createDrawerNavigator,
  RouterView,
} from '@thelacanians/vue-native-navigation'
import SearchScreen from './screens/SearchScreen.vue'
import ProfileScreen from './screens/ProfileScreen.vue'
import SettingsScreen from './screens/SettingsScreen.vue'

// ─── Drawer Navigator ────────────────────────────────────────────────────────

const { DrawerNavigator } = createDrawerNavigator()

// `main` hosts the RouterView so the stack demo (HomeScreen pushing Detail)
// renders inside the drawer's content area. DrawerScreen reads its `component`
// prop and renders it; anything placed in the navigator's default slot is only
// scanned for DrawerScreen vnodes and is never mounted, so screen content must
// always arrive through `component`.
const drawerScreens = [
  { name: 'main', label: 'Browse', icon: '🏠', component: RouterView },
  { name: 'search', label: 'Search', icon: '🔍', component: SearchScreen },
  { name: 'profile', label: 'Profile', icon: '👤', component: ProfileScreen },
  { name: 'settings', label: 'Settings', icon: '⚙️', component: SettingsScreen },
]
</script>

<template>
  <DrawerNavigator
    :screens="drawerScreens"
    :drawer-width="280"
    drawer-position="left"
    drawer-background-color="#FFFFFF"
  />
</template>
