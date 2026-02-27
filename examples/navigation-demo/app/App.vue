<script setup lang="ts">
import { createStyleSheet } from '@thelacanians/vue-native-runtime'
import {
  createTabNavigator,
  createDrawerNavigator,
  RouterView,
} from '@thelacanians/vue-native-navigation'
import HomeScreen from './screens/HomeScreen.vue'
import SearchScreen from './screens/SearchScreen.vue'
import ProfileScreen from './screens/ProfileScreen.vue'
import SettingsScreen from './screens/SettingsScreen.vue'

// ─── Tab Navigator ───────────────────────────────────────────────────────────

const { TabNavigator } = createTabNavigator()

const tabScreens = [
  { name: 'home', label: 'Home', icon: '🏠', component: HomeScreen },
  { name: 'search', label: 'Search', icon: '🔍', component: SearchScreen },
  { name: 'profile', label: 'Profile', icon: '👤', component: ProfileScreen },
]

// ─── Drawer Navigator ────────────────────────────────────────────────────────

const { DrawerNavigator } = createDrawerNavigator()

const drawerScreens = [
  { name: 'main', label: 'Main', icon: '🏠', component: HomeScreen },
  { name: 'settings', label: 'Settings', icon: '⚙️', component: SettingsScreen },
  { name: 'profile', label: 'Profile', icon: '👤', component: ProfileScreen },
]

const styles = createStyleSheet({
  container: { flex: 1 },
})
</script>

<template>
  <DrawerNavigator
    :screens="drawerScreens"
    :drawer-width="280"
    drawer-position="left"
    drawer-background-color="#FFFFFF"
  >
    <template #default>
      <VView :style="styles.container">
        <TabNavigator
          :screens="tabScreens"
          active-color="#007AFF"
          inactive-color="#8E8E93"
          tab-bar-background-color="#F9F9F9"
        />
        <!-- RouterView handles Detail push within the stack -->
        <RouterView />
      </VView>
    </template>
  </DrawerNavigator>
</template>
