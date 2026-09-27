import { createTabNavigator } from '@thelacanians/vue-native-navigation'
import FeedScreen from './screens/FeedScreen.vue'
import ExploreScreen from './screens/ExploreScreen.vue'
import ProfileScreen from './screens/ProfileScreen.vue'

// Kept out of main.ts: App.vue needs the navigator and the tab list, and
// importing them back from the entry module would make entry <-> root circular
// (App.vue can then observe `tabs` in its TDZ inside the IIFE bundle).
export const { TabNavigator } = createTabNavigator()

export const tabs = [
  { name: 'feed', label: 'Feed', icon: '🏠', component: FeedScreen },
  { name: 'explore', label: 'Explore', icon: '🔍', component: ExploreScreen },
  { name: 'profile', label: 'Profile', icon: '👤', component: ProfileScreen },
]
