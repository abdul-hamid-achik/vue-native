import { createApp } from '@thelacanians/vue-native-runtime'
import { createRouter } from '@thelacanians/vue-native-navigation'
import App from './App.vue'
import HomeScreen from './screens/HomeScreen.vue'
import DetailScreen from './screens/DetailScreen.vue'
import SearchScreen from './screens/SearchScreen.vue'
import ProfileScreen from './screens/ProfileScreen.vue'
import SettingsScreen from './screens/SettingsScreen.vue'

const router = createRouter({
  routes: [
    { name: 'Home', component: HomeScreen, options: { title: 'Home', headerShown: false } },
    { name: 'Detail', component: DetailScreen, options: { title: 'Detail' } },
    { name: 'Search', component: SearchScreen, options: { title: 'Search', headerShown: false } },
    { name: 'Profile', component: ProfileScreen, options: { title: 'Profile', headerShown: false } },
    { name: 'Settings', component: SettingsScreen, options: { title: 'Settings', headerShown: false } },
  ],
  linking: {
    prefixes: ['navdemo://', 'https://navdemo.example.com'],
    screens: {
      Home: '',
      Detail: 'detail/:id',
      Search: 'search',
      Profile: 'profile',
      Settings: 'settings',
    },
  },
})

// Navigation guard: log every navigation
router.afterEach((to, from) => {
  console.log(`[Nav] ${from.config.name} → ${to.config.name}`)
})

const app = createApp(App)
app.use(router)
app.start()
