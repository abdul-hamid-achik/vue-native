# Your First App

This guide walks you through building a complete Vue Native app from scratch — a contact list with navigation and data fetching. By the end, you'll understand the core workflow: components, styling, navigation, and working with native APIs.

## Prerequisites

- Node.js 18+ or [Bun](https://bun.sh)
- **iOS:** Xcode 15+, iOS 16+ Simulator
- **Android:** Android Studio, API 21+ emulator
- **macOS:** Xcode 15+, macOS 13.0+

## Part 1: Project Setup & Your First Screen

### Create the project

```bash
npx @thelacanians/vue-native-cli create my-contacts
cd my-contacts
```

This scaffolds the project structure:

```
my-contacts/
├── app/
│   ├── main.ts          # Entry point
│   └── App.vue          # Root component
├── ios/                  # Xcode project (iOS)
├── macos/                # Xcode project (macOS)
├── android/              # Gradle project (Android)
├── vite.config.ts        # Build configuration
└── package.json
```

### Write your first component

Open `app/App.vue` and replace the contents:

```vue
<script setup lang="ts">
import { ref, createStyleSheet } from '@thelacanians/vue-native-runtime'

const count = ref(0)

const styles = createStyleSheet({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#F5F5F5',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1A1A1A',
    marginBottom: 8,
  },
  counter: {
    fontSize: 48,
    fontWeight: '200',
    color: '#007AFF',
    marginBottom: 24,
  },
  button: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 32,
    paddingVertical: 14,
    borderRadius: 12,
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.title">My First App</VText>
    <VText :style="styles.counter">{{ count }}</VText>
    <VButton :style="styles.button" :onPress="() => count++">
      <VText :style="styles.buttonText">Tap Me</VText>
    </VButton>
  </VView>
</template>
```

### Understanding the entry point

The entry point (`app/main.ts`) boots the app:

```ts
import { createApp } from '@thelacanians/vue-native-runtime'
import App from './App.vue'

createApp(App).start()
```

`createApp(App).start()` does three things:
1. Creates a Vue app using the **native renderer** (not the DOM renderer)
2. Registers all built-in components (`VView`, `VText`, etc.) so they work in templates
3. Mounts the app and tells the native side to start rendering

### Run it

```bash
# Terminal 1: Start the dev server (Vite watch + hot reload WebSocket)
bun run dev

# Terminal 2: Build and run on simulator (first time only)
vue-native run ios
# or: vue-native run android
# or: vue-native run macos
```

You should see a centered counter that increments on tap. Any edits to `.vue` files will hot-reload instantly.

### Key concepts

- **No HTML elements.** Use `VView` (like `<div>`), `VText` (like `<span>`), `VButton` (like `<button>`)
- **Style objects, not CSS.** Use `createStyleSheet` with camelCase properties. Numbers are in **density-independent points** (dp) — 16 dp is approximately 16 CSS pixels
- **Flexbox layout.** Yoga (iOS) and FlexboxLayout (Android) implement CSS Flexbox. Default direction is `column` (vertical)

## Part 2: Adding Navigation

Let's add a second screen and navigate between them.

### Install navigation

The navigation package is included in the monorepo. If using a standalone project:

```bash
bun add @thelacanians/vue-native-navigation
```

### Create screen components

Create `app/views/HomeView.vue`:

```vue
<script setup lang="ts">
import { ref, createStyleSheet } from '@thelacanians/vue-native-runtime'
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()

const contacts = ref([
  { id: 1, name: 'Alice Johnson', role: 'Engineer' },
  { id: 2, name: 'Bob Smith', role: 'Designer' },
  { id: 3, name: 'Carol Williams', role: 'Product Manager' },
])

const styles = createStyleSheet({
  container: { flex: 1, backgroundColor: '#F5F5F5' },
  header: {
    padding: 20,
    paddingTop: 12,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderColor: '#E5E5E5',
  },
  headerText: { fontSize: 32, fontWeight: 'bold', color: '#1A1A1A' },
  list: { flex: 1, padding: 16, gap: 12 },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#007AFF',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: { color: '#FFFFFF', fontSize: 18, fontWeight: '600' },
  name: { fontSize: 17, fontWeight: '600', color: '#1A1A1A' },
  role: { fontSize: 14, color: '#8E8E93' },
})
</script>

<template>
  <VView :style="styles.container">
    <VView :style="styles.header">
      <VText :style="styles.headerText">Contacts</VText>
    </VView>
    <VScrollView :style="styles.list">
      <VButton
        v-for="contact in contacts"
        :key="contact.id"
        :style="styles.card"
        :onPress="() => router.push('detail', { id: contact.id, name: contact.name, role: contact.role })"
      >
        <VView :style="styles.avatar">
          <VText :style="styles.avatarText">{{ contact.name[0] }}</VText>
        </VView>
        <VView>
          <VText :style="styles.name">{{ contact.name }}</VText>
          <VText :style="styles.role">{{ contact.role }}</VText>
        </VView>
      </VButton>
    </VScrollView>
  </VView>
</template>
```

Create `app/views/DetailView.vue`:

```vue
<script setup lang="ts">
import { createStyleSheet } from '@thelacanians/vue-native-runtime'
import { useRoute, useRouter } from '@thelacanians/vue-native-navigation'

const route = useRoute()
const router = useRouter()

const styles = createStyleSheet({
  container: { flex: 1, backgroundColor: '#F5F5F5' },
  backButton: { padding: 16 },
  backText: { fontSize: 17, color: '#007AFF' },
  content: { alignItems: 'center', padding: 32, gap: 12 },
  avatar: {
    width: 88,
    height: 88,
    borderRadius: 44,
    backgroundColor: '#007AFF',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
  },
  avatarText: { color: '#FFFFFF', fontSize: 36, fontWeight: '600' },
  name: { fontSize: 24, fontWeight: 'bold', color: '#1A1A1A' },
  role: { fontSize: 17, color: '#8E8E93' },
})
</script>

<template>
  <VView :style="styles.container">
    <VButton :style="styles.backButton" :onPress="() => router.pop()">
      <VText :style="styles.backText">Back</VText>
    </VButton>
    <VView :style="styles.content">
      <VView :style="styles.avatar">
        <VText :style="styles.avatarText">{{ route.params.name?.[0] }}</VText>
      </VView>
      <VText :style="styles.name">{{ route.params.name }}</VText>
      <VText :style="styles.role">{{ route.params.role }}</VText>
    </VView>
  </VView>
</template>
```

### Set up the router

Update `app/main.ts`:

```ts
import { createApp } from '@thelacanians/vue-native-runtime'
import { createRouter, RouterView } from '@thelacanians/vue-native-navigation'
import HomeView from './views/HomeView.vue'
import DetailView from './views/DetailView.vue'

const { router } = createRouter([
  { name: 'home', component: HomeView },
  { name: 'detail', component: DetailView },
])

const app = createApp(RouterView)
app.use(router)
app.start()
```

Now `router.push('detail', { id: 1, name: 'Alice' })` navigates to the detail screen, and `router.pop()` goes back.

## Part 3: Fetching Data from an API

Replace the hardcoded contacts with a real API call.

Update `app/views/HomeView.vue`:

```vue
<script setup lang="ts">
import { ref, onMounted, createStyleSheet } from '@thelacanians/vue-native-runtime'
import { useHttp } from '@thelacanians/vue-native-runtime'
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()
const { loading, error, get } = useHttp({
  baseURL: 'https://jsonplaceholder.typicode.com',
})

const contacts = ref<{ id: number; name: string; company: { catchPhrase: string } }[]>([])

onMounted(async () => {
  try {
    const response = await get('/users', { params: { _limit: '10' } })
    contacts.value = response.data
  } catch (e) {
    console.log('Failed to load contacts')
  }
})

const styles = createStyleSheet({
  container: { flex: 1, backgroundColor: '#F5F5F5' },
  header: {
    padding: 20,
    paddingTop: 12,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderColor: '#E5E5E5',
  },
  headerText: { fontSize: 32, fontWeight: 'bold', color: '#1A1A1A' },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  loadingText: { fontSize: 16, color: '#8E8E93' },
  errorText: { fontSize: 16, color: '#FF3B30' },
  list: { flex: 1, padding: 16, gap: 12 },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#007AFF',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: { color: '#FFFFFF', fontSize: 18, fontWeight: '600' },
  name: { fontSize: 17, fontWeight: '600', color: '#1A1A1A' },
  subtitle: { fontSize: 14, color: '#8E8E93' },
})
</script>

<template>
  <VView :style="styles.container">
    <VView :style="styles.header">
      <VText :style="styles.headerText">Contacts</VText>
    </VView>

    <VView v-if="loading" :style="styles.centered">
      <VActivityIndicator />
      <VText :style="styles.loadingText">Loading contacts...</VText>
    </VView>

    <VView v-else-if="error" :style="styles.centered">
      <VText :style="styles.errorText">{{ error }}</VText>
    </VView>

    <VScrollView v-else :style="styles.list">
      <VButton
        v-for="contact in contacts"
        :key="contact.id"
        :style="styles.card"
        :onPress="() => router.push('detail', { id: contact.id, name: contact.name, role: contact.company.catchPhrase })"
      >
        <VView :style="styles.avatar">
          <VText :style="styles.avatarText">{{ contact.name[0] }}</VText>
        </VView>
        <VView>
          <VText :style="styles.name">{{ contact.name }}</VText>
          <VText :style="styles.subtitle">{{ contact.company.catchPhrase }}</VText>
        </VView>
      </VButton>
    </VScrollView>
  </VView>
</template>
```

## What's Next

You've built an app with components, navigation, and data fetching. Here's where to go next:

- **[Styling Guide](/guide/styling.md)** — Units, colors, Flexbox patterns, dark mode
- **[Components](/components/)** — All 28+ built-in components with examples
- **[Composables](/composables/)** — 37+ native API wrappers (camera, storage, sensors, etc.)
- **[Navigation](/navigation/)** — Tabs, drawer, guards, deep linking, state persistence
- **[Deployment](/guide/deployment.md)** — Ship to App Store and Play Store

For a deeper dive, see the [example apps](https://github.com/abdul-hamid-achik/vue-native/tree/main/examples) — including a todo app, chat app, and auth flow.
