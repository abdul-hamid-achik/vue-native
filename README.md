# Vue Native

Build native iOS and Android apps with Vue 3. Write Vue components, render real native views — no WebView, no compromise.

## Features

- **Vue 3 First** — Composition API, `<script setup>`, `ref`, `computed`, `watch` — all just work
- **Real Native UI** — Every component maps to native UIKit (iOS) or Android Views. No DOM, no WebView
- **Cross-Platform** — Same Vue code targets both iOS and Android from a single codebase
- **20 Built-in Components** — VView, VText, VButton, VInput, VScrollView, VImage, VList, VModal, and more
- **Native Modules** — Haptics, AsyncStorage, Clipboard, Network, Camera, Geolocation, and more
- **Navigation** — Stack navigation via `@thelacanians/navigation`
- **Flexbox Layout** — Yoga (iOS) and FlexboxLayout (Android) for consistent cross-platform layouts
- **Hot Reload** — Edit Vue files, see changes instantly on device or emulator
- **TypeScript** — Full type coverage across components, composables, and bridge

## Platform Support

| Feature | iOS | Android |
|---------|-----|---------|
| All 20 components | ✅ | ✅ |
| Native Modules | ✅ | ✅ |
| Navigation | ✅ | ✅ |
| Hot Reload | ✅ | ✅ |
| Dark Mode | ✅ | ✅ |
| JS Engine | JavaScriptCore | V8 (J2V8) |
| Layout | Yoga/FlexLayout | FlexboxLayout |

## Requirements

### iOS
- iOS 16.0+
- Xcode 15+
- Swift 5.9+

### Android
- Android 5.0+ (API 21+)
- Android Studio Hedgehog+
- Kotlin 1.9+

### Shared
- Node.js 18+ / Bun

## Quick Start

### Create a new project

```bash
npx @thelacanians/cli create my-app
cd my-app
```

### Project structure

```
my-app/
├── app/
│   ├── main.ts        # Entry point
│   ├── App.vue        # Root component
│   └── views/         # Screen components
├── ios/               # Xcode project
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── dist/              # Built JS bundle (auto-generated)
└── vite.config.ts
```

### Write your first component

```vue
<script setup lang="ts">
import { ref } from '@thelacanians/runtime'

const count = ref(0)
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.title">Count: {{ count }}</VText>
    <VButton :style="styles.button" @press="count++">
      <VText>Increment</VText>
    </VButton>
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/runtime'

const styles = createStyleSheet({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  title: { fontSize: 24, marginBottom: 20 },
  button: { backgroundColor: '#007AFF', paddingHorizontal: 24, paddingVertical: 12, borderRadius: 8 },
})
</script>
```

### Start development

```bash
bun run dev      # Start Vite watch mode + dev server
# Open ios/ in Xcode and run on simulator
```

## Components

### Layout
| Component | Description |
|-----------|-------------|
| `<VView>` | Container view. Equivalent to `<div>`. Supports all Flexbox props |
| `<VScrollView>` | Scrollable container. `horizontal` prop for horizontal scroll |
| `<VSafeArea>` | Respects device safe areas (notch, home indicator) |
| `<VKeyboardAvoiding>` | Shifts content up when keyboard appears |

### Text & Input
| Component | Description |
|-----------|-------------|
| `<VText>` | Text display. Supports `fontSize`, `fontWeight`, `color`, etc. |
| `<VInput>` | Text input. Supports `v-model`, `placeholder`, `keyboardType`, `secureTextEntry` |

### Interactive
| Component | Description |
|-----------|-------------|
| `<VButton>` | Pressable view with `@press` and `@longPress` events |
| `<VSwitch>` | Toggle switch. Supports `v-model` |
| `<VSlider>` | Range slider. Supports `v-model`, `minimumValue`, `maximumValue` |
| `<VSegmentedControl>` | Tab strip selector |

### Media
| Component | Description |
|-----------|-------------|
| `<VImage>` | Async image loading with caching. `source={{ uri: 'https://...' }}` |
| `<VWebView>` | Embedded WKWebView. `source={{ uri: '...' }}` or `source={{ html: '...' }}` |

### Lists
| Component | Description |
|-----------|-------------|
| `<VList>` | Virtualized list backed by UITableView. Efficient for large datasets |

### Feedback
| Component | Description |
|-----------|-------------|
| `<VActivityIndicator>` | Loading spinner |
| `<VProgressBar>` | Horizontal progress bar |
| `<VAlertDialog>` | Native alert with customizable buttons |
| `<VActionSheet>` | Native bottom action sheet |
| `<VModal>` | Window-level overlay modal |

### System
| Component | Description |
|-----------|-------------|
| `<VStatusBar>` | Control status bar style and visibility |
| `<VPicker>` | Date/time picker |

## Composables

### Device & System
```typescript
const { isConnected, connectionType } = useNetwork()
const { state } = useAppState()   // 'active' | 'inactive' | 'background'
const { colorScheme, isDark } = useColorScheme()
const { model, screenWidth, screenHeight } = useDeviceInfo()
```

### Storage
```typescript
const { getItem, setItem, removeItem } = useAsyncStorage()
```

### Sensors & Hardware
```typescript
const { coords, getCurrentPosition } = useGeolocation()
const { authenticate, getSupportedBiometry } = useBiometry()
const { vibrate } = useHaptics()
```

### Media
```typescript
const { launchCamera, launchImageLibrary } = useCamera()
```

### Permissions
```typescript
const { request, check } = usePermissions()
const status = await request('camera')  // 'granted' | 'denied' | 'restricted'
```

### Notifications
```typescript
const { requestPermission, scheduleLocal, onNotification } = useNotifications()
await scheduleLocal({ title: 'Reminder', body: 'Hello!', delay: 5 })
```

### UI
```typescript
const { isVisible, height } = useKeyboard()
const { copy, paste } = useClipboard()
const { share } = useShare()
const { openURL, canOpenURL } = useLinking()
const { timing, spring, keyframe, sequence, parallel } = useAnimation()
const http = useHttp({ baseURL: 'https://api.example.com' })
```

## Navigation

```typescript
import { createRouter, RouterView, useRouter, useRoute } from '@thelacanians/navigation'

const { router } = createRouter([
  { name: 'home', component: HomeView },
  { name: 'detail', component: DetailView },
])
```

```vue
<!-- App.vue -->
<template>
  <RouterView />
</template>
```

```vue
<!-- HomeView.vue -->
<script setup>
const router = useRouter()
</script>
<template>
  <VView style="flex: 1">
    <VButton @press="router.push('detail', { id: 42 })">
      <VText>Go to Detail</VText>
    </VButton>
  </VView>
</template>
```

## Styling

Vue Native uses **Yoga Flexbox** layout — the same engine as React Native. All CSS Flexbox properties are supported.

```typescript
import { createStyleSheet } from '@thelacanians/runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    flexDirection: 'column',
    backgroundColor: '#F5F5F5',
    padding: 16,
    gap: 12,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
})
```

## Building for Release

```bash
# Build optimized bundle
bun run build

# In Xcode: Product → Archive → Distribute App
```

## Architecture

Vue Native bridges Vue 3's custom renderer to the native view system on each platform:

```
Vue Component (SFC)
      ↓ Vue renderer (patchProp, insert, remove)
  NativeBridge (TypeScript)
      ↓ JSON batch via queueMicrotask
      ├── iOS: NativeBridge (Swift / @MainActor)
      │         ↓ ComponentRegistry → UIKit Factory
      │      UIKit Views  →  Yoga Layout (FlexLayout)
      │
      └── Android: NativeBridge (Kotlin / Main Thread)
                ↓ ComponentRegistry → Android Factory
             Android Views  →  FlexboxLayout
```

## Packages

| Package | Description |
|---------|-------------|
| `@thelacanians/runtime` | Core runtime: renderer, bridge, components, composables |
| `@thelacanians/navigation` | Stack and tab navigation |
| `@thelacanians/vite-plugin` | Vite build integration |
| `@thelacanians/cli` | Project scaffolding and dev tooling |

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). The project is a monorepo managed with Bun workspaces and Turborepo.

## License

MIT
