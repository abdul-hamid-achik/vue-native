import { createApp, NativeBridge } from '@thelacanians/vue-native-runtime'
import { createRouter } from '@thelacanians/vue-native-navigation'
import App from './App.vue'
import LoginScreen from './screens/LoginScreen.vue'
import HomeScreen from './screens/HomeScreen.vue'

const router = createRouter([
  { name: 'Login', component: LoginScreen, options: { title: 'Login', headerShown: false } },
  { name: 'Home', component: HomeScreen, options: { title: 'Home', headerShown: false } },
])

// Navigation guard: redirect to Login if not authenticated
router.beforeEach(async (to, _from, next) => {
  if (to.config.name === 'Login') {
    next()
    return
  }

  // Check for stored auth token via NativeBridge
  try {
    const token = await NativeBridge.invokeNativeModule('AsyncStorage', 'getItem', ['auth_token'])
    if (token) {
      next()
    } else {
      next('Login')
    }
  } catch {
    next('Login')
  }
})

const app = createApp(App)
app.use(router)
app.start()
