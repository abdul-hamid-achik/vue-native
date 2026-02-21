import { createApp } from '@vue-native/runtime'
import { createRouter } from '@vue-native/navigation'
import App from './App.vue'
import TaskListScreen from './screens/TaskListScreen.vue'
import TaskDetailScreen from './screens/TaskDetailScreen.vue'

const router = createRouter([
  { name: 'TaskList', component: TaskListScreen, options: { title: 'Tasks', headerShown: false } },
  { name: 'TaskDetail', component: TaskDetailScreen, options: { title: 'Task Detail' } },
])

const app = createApp(App)
app.use(router)
app.start()
