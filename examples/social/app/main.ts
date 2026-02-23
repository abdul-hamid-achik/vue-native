import { createApp } from '@thelacanians/runtime'
import { createRouter } from '@thelacanians/navigation'
import App from './App.vue'
import FeedScreen from './screens/FeedScreen.vue'
import ExploreScreen from './screens/ExploreScreen.vue'
import ProfileScreen from './screens/ProfileScreen.vue'

const router = createRouter([
  { name: 'Feed', component: FeedScreen, options: { title: 'Feed' } },
  { name: 'Explore', component: ExploreScreen, options: { title: 'Explore' } },
  { name: 'Profile', component: ProfileScreen, options: { title: 'Profile' } },
])

const app = createApp(App)
app.use(router)
app.start()
