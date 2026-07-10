import { createApp } from '@thelacanians/vue-native-runtime'
import { createTabNavigator } from '@thelacanians/vue-native-navigation'
import App from './App.vue'
import FeedScreen from './screens/FeedScreen.vue'
import ExploreScreen from './screens/ExploreScreen.vue'
import ProfileScreen from './screens/ProfileScreen.vue'

export const { TabNavigator } = createTabNavigator()

export const tabs = [
  { name: 'feed', label: 'Feed', icon: '🏠', component: FeedScreen },
  { name: 'explore', label: 'Explore', icon: '🔍', component: ExploreScreen },
  { name: 'profile', label: 'Profile', icon: '👤', component: ProfileScreen },
]

const app = createApp(App)
app.start()
