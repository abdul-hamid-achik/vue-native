# TypeScript

Vue Native is written in TypeScript and provides full type safety for components, composables, styles, and configuration. This guide covers the type system and how to get the most out of it in your projects.

## Configuration

A recommended `tsconfig.json` for Vue Native projects:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "jsx": "preserve",
    "types": ["@thelacanians/vue-native-runtime/types"],
    "paths": {
      "@/*": ["./src/*"]
    },
    "skipLibCheck": true
  },
  "include": ["src/**/*.ts", "src/**/*.vue"],
  "exclude": ["node_modules"]
}
```

Key settings explained:

| Option              | Value       | Reason                                                       |
| ------------------- | ----------- | ------------------------------------------------------------ |
| `target`            | `ES2020`    | JavaScriptCore on iOS 16+ supports ES2020 features.          |
| `module`            | `ESNext`    | Vite handles module bundling; keep source as ESM.            |
| `moduleResolution`  | `bundler`   | Matches Vite's resolution strategy for imports.              |
| `strict`            | `true`      | Enables all strict type-checking options.                    |
| `jsx`               | `preserve`  | Allows Vue SFC `<script setup lang="ts">` to work correctly. |
| `types`             | See above   | Registers Vue Native's global type augmentations.            |

## Style Types

Vue Native exports three style interfaces from `@thelacanians/vue-native-runtime`. These types map directly to native layout and rendering properties.

### ViewStyle

The base style type for all container components (`VView`, `VScrollView`, `VSafeArea`, etc.). Includes layout (Flexbox), spacing, borders, backgrounds, and transforms.

```ts
import type { ViewStyle } from '@thelacanians/vue-native-runtime'

const container: ViewStyle = {
  // Layout
  flex: 1,
  flexDirection: 'column',
  justifyContent: 'center',
  alignItems: 'center',

  // Spacing
  padding: 20,
  margin: 10,
  gap: 12,

  // Appearance
  backgroundColor: '#f5f5f5',
  borderRadius: 12,
  borderWidth: 1,
  borderColor: '#e0e0e0',

  // Shadow (iOS)
  shadowColor: '#000',
  shadowOffset: { width: 0, height: 2 },
  shadowOpacity: 0.1,
  shadowRadius: 4,

  // Elevation (Android)
  elevation: 3,

  // Dimensions
  width: '100%',
  height: 200,
  minHeight: 100,
  maxWidth: 400,

  // Positioning
  position: 'relative',
  overflow: 'hidden',

  // Opacity
  opacity: 1,
}
```

### TextStyle

Extends `ViewStyle` with font and text-specific properties. Used by `VText` and text-containing components.

```ts
import type { TextStyle } from '@thelacanians/vue-native-runtime'

const heading: TextStyle = {
  // All ViewStyle properties are available, plus:
  fontSize: 28,
  fontWeight: 'bold',
  fontStyle: 'italic',
  fontFamily: 'System',
  color: '#1a1a1a',
  textAlign: 'center',
  textDecorationLine: 'underline',
  textTransform: 'uppercase',
  lineHeight: 34,
  letterSpacing: 0.5,
}
```

### ImageStyle

Extends `ViewStyle` with image-specific properties. Used by `VImage`.

```ts
import type { ImageStyle } from '@thelacanians/vue-native-runtime'

const avatar: ImageStyle = {
  // All ViewStyle properties are available, plus:
  resizeMode: 'cover', // 'cover' | 'contain' | 'stretch' | 'center'
  tintColor: '#007AFF',
  width: 48,
  height: 48,
  borderRadius: 24,
}
```

### Using Style Types in Components

You can type style props and variables to catch errors at compile time:

```vue
<script setup lang="ts">
import type { ViewStyle, TextStyle } from '@thelacanians/vue-native-runtime'
import { VView, VText } from '@thelacanians/vue-native-runtime'

// TypeScript will error if you use an invalid property
const card: ViewStyle = {
  padding: 16,
  backgroundColor: '#fff',
  borderRadius: 12,
  shadowColor: '#000',
  shadowOpacity: 0.1,
  shadowRadius: 8,
  shadowOffset: { width: 0, height: 2 },
}

const title: TextStyle = {
  fontSize: 20,
  fontWeight: '600',
  color: '#333',
  marginBottom: 8,
}

const subtitle: TextStyle = {
  fontSize: 14,
  color: '#888',
}
</script>

<template>
  <VView :style="card">
    <VText :style="title">Card Title</VText>
    <VText :style="subtitle">A short description</VText>
  </VView>
</template>
```

## createStyleSheet

The `createStyleSheet` utility provides a type-safe, organized way to define groups of styles — similar to React Native's `StyleSheet.create`. It validates that each style value conforms to `ViewStyle`, `TextStyle`, or `ImageStyle` and returns a typed object.

```ts
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: '#fafafa',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1a1a1a',
    marginBottom: 12,
  },
  avatar: {
    width: 64,
    height: 64,
    borderRadius: 32,
    resizeMode: 'cover',
  },
  button: {
    padding: 14,
    backgroundColor: '#007AFF',
    borderRadius: 8,
    alignItems: 'center',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
})
```

Then use it in your template:

```vue
<template>
  <VView :style="styles.container">
    <VImage source="avatar.png" :style="styles.avatar" />
    <VText :style="styles.title">Hello, Vue Native</VText>
    <VButton :onPress="handlePress" :style="styles.button">
      <VText :style="styles.buttonText">Get Started</VText>
    </VButton>
  </VView>
</template>
```

Benefits of `createStyleSheet`:

- **Type safety** — invalid property names or values are caught at compile time.
- **Autocomplete** — your editor suggests valid style properties as you type.
- **Organization** — keeps styles separate from template logic.
- **Reuse** — export and share stylesheets across components.

## Component Prop Types

Every Vue Native component has fully typed props. Your editor will provide autocomplete and type checking for all prop values.

```vue
<script setup lang="ts">
import { ref } from 'vue'
import {
  VView,
  VText,
  VInput,
  VButton,
  VSwitch,
  VImage,
  VSlider,
} from '@thelacanians/vue-native-runtime'

const text = ref('')
const isEnabled = ref(false)
const sliderValue = ref(0.5)
</script>

<template>
  <!-- VInput: value, onChangeText, placeholder, secureTextEntry, etc. -->
  <VInput
    :value="text"
    :onChangeText="(t: string) => (text = t)"
    placeholder="Type here..."
    :maxLength="100"
    keyboardType="email-address"
  />

  <!-- VSwitch: value (boolean), onValueChange, trackColor, thumbColor -->
  <VSwitch
    :value="isEnabled"
    :onValueChange="(v: boolean) => (isEnabled = v)"
    trackColor="#007AFF"
    thumbColor="#fff"
  />

  <!-- VImage: source (string | { uri: string }), resizeMode -->
  <VImage
    source="logo.png"
    resizeMode="contain"
    :style="{ width: 120, height: 120 }"
  />

  <!-- VSlider: value, onValueChange, minimumValue, maximumValue -->
  <VSlider
    :value="sliderValue"
    :onValueChange="(v: number) => (sliderValue = v)"
    :minimumValue="0"
    :maximumValue="1"
    :step="0.01"
  />
</template>
```

TypeScript will flag errors like passing a number where a string is expected, or using an invalid `keyboardType` value.

## Composable Return Types

All composables return properly typed refs, reactive objects, and functions. This gives you autocomplete and type checking without manual annotations.

```vue
<script setup lang="ts">
import { useDeviceInfo } from '@thelacanians/vue-native-runtime'
import { useRouter, useRoute } from '@thelacanians/vue-native-navigation'

// useDeviceInfo returns typed refs
const {
  platform,   // Ref<'ios' | 'android'>
  osVersion,  // Ref<string>
  deviceModel, // Ref<string>
  screenWidth, // Ref<number>
  screenHeight, // Ref<number>
} = useDeviceInfo()

// useRouter returns typed navigation functions
const router = useRouter()
// router.push(route: string | RouteLocation): void
// router.replace(route: string | RouteLocation): void
// router.back(): void

// useRoute returns the current route as a typed reactive object
const route = useRoute()
// route.path: string
// route.params: Record<string, string>
// route.query: Record<string, string>
// route.name: string | undefined
</script>
```

### Typing Custom Composables

When building your own composables, leverage Vue Native's types:

```ts
import { ref, onMounted } from 'vue'
import { useHttp } from '@thelacanians/vue-native-runtime'
import type { Ref } from 'vue'

interface User {
  id: number
  name: string
  email: string
}

interface UseUsersReturn {
  users: Ref<User[]>
  loading: Ref<boolean>
  error: Ref<string | null>
  refresh: () => Promise<void>
}

export function useUsers(): UseUsersReturn {
  const users = ref<User[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)
  const { get } = useHttp()

  async function refresh() {
    loading.value = true
    error.value = null
    try {
      const response = await get<User[]>('https://api.example.com/users')
      users.value = response.data
    } catch (e) {
      error.value = (e as Error).message
    } finally {
      loading.value = false
    }
  }

  onMounted(refresh)

  return { users, loading, error, refresh }
}
```

## Typed Navigation

The navigation package exports types for route configuration and navigation guards:

```ts
import { createRouter } from '@thelacanians/vue-native-navigation'
import type { RouteConfig, NavigationGuard } from '@thelacanians/vue-native-navigation'
import HomeScreen from './screens/Home.vue'
import ProfileScreen from './screens/Profile.vue'
import LoginScreen from './screens/Login.vue'

// Route configuration is fully typed
const routes: RouteConfig[] = [
  { path: '/', name: 'Home', component: HomeScreen },
  { path: '/profile/:id', name: 'Profile', component: ProfileScreen },
  { path: '/login', name: 'Login', component: LoginScreen },
]

// Navigation guards are typed
const authGuard: NavigationGuard = (to, from) => {
  const isAuthenticated = checkAuth()
  if (to.path !== '/login' && !isAuthenticated) {
    return '/login'
  }
}

const router = createRouter({ routes })
router.beforeEach(authGuard)

export default router
```

## Typing Event Handlers

Event callbacks from components are typed. Use them directly or extract the types:

```vue
<script setup lang="ts">
import { VButton, VInput, VList } from '@thelacanians/vue-native-runtime'

// onPress receives no arguments
function handlePress(): void {
  console.log('Button pressed')
}

// onChangeText receives the new text as a string
function handleTextChange(text: string): void {
  console.log('New text:', text)
}

// VList onEndReached receives no arguments
function handleEndReached(): void {
  console.log('Load more items')
}
</script>

<template>
  <VButton :onPress="handlePress">
    <VText>Tap Me</VText>
  </VButton>

  <VInput :onChangeText="handleTextChange" placeholder="Type..." />

  <VList :data="items" :renderItem="renderItem" :onEndReached="handleEndReached" />
</template>
```

## Generic Components

When building reusable components, use TypeScript generics for type-safe data flow:

```vue
<!-- TypedList.vue -->
<script setup lang="ts" generic="T extends { id: string | number }">
import { VList, VView, VText } from '@thelacanians/vue-native-runtime'

const props = defineProps<{
  items: T[]
  renderItem: (item: T, index: number) => any
  keyExtractor?: (item: T) => string | number
}>()

function defaultKeyExtractor(item: T): string | number {
  return item.id
}
</script>

<template>
  <VList
    :data="items"
    :renderItem="renderItem"
    :keyExtractor="keyExtractor ?? defaultKeyExtractor"
  />
</template>
```

Usage:

```vue
<script setup lang="ts">
import TypedList from './TypedList.vue'

interface Task {
  id: number
  title: string
  done: boolean
}

const tasks: Task[] = [
  { id: 1, title: 'Learn Vue Native', done: false },
  { id: 2, title: 'Build an app', done: false },
]

// TypeScript knows `task` is of type Task
function renderTask(task: Task, index: number) {
  // ...
}
</script>

<template>
  <TypedList :items="tasks" :renderItem="renderTask" />
</template>
```

## Type-Safe Styles with Themes

Combine TypeScript with a theme object for consistent, type-safe styling across your app:

```ts
// theme.ts
export const theme = {
  colors: {
    primary: '#007AFF',
    secondary: '#5856D6',
    background: '#F2F2F7',
    surface: '#FFFFFF',
    text: '#1C1C1E',
    textSecondary: '#8E8E93',
    error: '#FF3B30',
    success: '#34C759',
  },
  spacing: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
  },
  fontSize: {
    body: 16,
    caption: 12,
    heading: 24,
    title: 32,
  },
  borderRadius: {
    sm: 6,
    md: 12,
    lg: 20,
    full: 9999,
  },
} as const

// The type is inferred with literal types thanks to `as const`
export type Theme = typeof theme
```

```ts
// styles.ts
import { createStyleSheet } from '@thelacanians/vue-native-runtime'
import { theme } from './theme'

export const commonStyles = createStyleSheet({
  screen: {
    flex: 1,
    backgroundColor: theme.colors.background,
    padding: theme.spacing.md,
  },
  card: {
    backgroundColor: theme.colors.surface,
    borderRadius: theme.borderRadius.md,
    padding: theme.spacing.md,
    shadowColor: '#000',
    shadowOpacity: 0.05,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
  },
  heading: {
    fontSize: theme.fontSize.heading,
    fontWeight: 'bold',
    color: theme.colors.text,
    marginBottom: theme.spacing.sm,
  },
  body: {
    fontSize: theme.fontSize.body,
    color: theme.colors.text,
    lineHeight: 22,
  },
  primaryButton: {
    backgroundColor: theme.colors.primary,
    borderRadius: theme.borderRadius.sm,
    padding: theme.spacing.md,
    alignItems: 'center',
  },
  primaryButtonText: {
    color: '#fff',
    fontSize: theme.fontSize.body,
    fontWeight: '600',
  },
})
```

## Best Practices

1. **Enable strict mode.** Set `"strict": true` in your `tsconfig.json`. This catches null errors, implicit `any` types, and other common mistakes.

2. **Use `createStyleSheet` over inline objects.** You get autocomplete, compile-time validation, and cleaner templates.

3. **Type your composable return values.** Explicitly defining return interfaces makes composables easier to consume and documents their API.

4. **Leverage `as const` for constants.** Theme objects, route names, and other constants benefit from literal type inference.

5. **Avoid `any`.** If you must escape the type system, prefer `unknown` and narrow with type guards.

6. **Use `lang="ts"` in SFCs.** Always add `lang="ts"` to your `<script setup>` blocks:
   ```vue
   <script setup lang="ts">
   // TypeScript is now active in this component
   </script>
   ```

7. **Export types alongside values.** When creating a module, export both the runtime values and their types so consumers can use them in type annotations.
