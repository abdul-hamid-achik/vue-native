# Navigation Demo

Comprehensive navigation example demonstrating stack navigation, params, and guards.

> **Requires a native host.** This directory ships Vue source and build config
> only — there is no `ios/`, `android/`, or `macos/` app shell here. `bun run
> dev:ios`, `dev:android` and `dev:macos` build the JS bundle but have nothing
> to run it in. To see this app on a device or simulator:
>
> ```bash
> bunx vue-native create my-app   # scaffolds iOS + Android hosts
> ```
>
> Then copy `app/`, `vite.config.ts` and `env.d.ts` from this example over the
> scaffold's equivalents, run `bun run build` here, and open the generated
> project in Xcode or Android Studio. `vue-native create` does not scaffold a
> macOS shell yet.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput, VScrollView
- **Composables:** `useRouter`, `useRoute`, `useDrawer`
- **Navigation:** `createRouter`, `createTabNavigator`, `createDrawerNavigator`, `RouterView`
- **Patterns:**
  - Stack navigation with route params (`router.push('Detail', { id })`)
  - Deep-link configuration (`navdemo://` prefixes)
  - An `afterEach` navigation guard that logs every transition
  - Tab and drawer navigators

> ⚠️ **Known broken — the drawer body never mounts.** `DrawerNavigator` calls its
> default slot only to scan for declarative `<DrawerScreen>` children and then
> renders its own fixed tree, so the `<template #default>` content (the
> `TabNavigator` and `RouterView`) is discarded. `RouterView` also cannot sit
> beside the tabs: it renders every stack entry as an absolutely-positioned
> full-bleed overlay, so it would permanently cover them. The screens therefore
> come only from `:screens="drawerScreens"`.
>
> Fixing this means choosing which navigator owns the root — `RouterView` with
> the drawer as one of its routes, or the drawer with a tab host as its main
> screen. Relatedly, `onScreenFocus` / `onScreenBlur` in `HomeScreen.vue` and
> `SearchScreen.vue` are no-ops because those screens are rendered by the
> navigators, not by `RouterView`, so the route entry they inject is absent.

## Key Features

- Multi-screen navigation with route params
- Deep-link configuration
- An `afterEach` guard logging every transition
- Tab and drawer navigators

Back-button handling (`useBackHandler`) is not demonstrated here.

## Screenshots

| Home Screen | Detail Screen | Settings |
|-------------|---------------|----------|
| Run on iOS to see | Run on iOS to see | Run on iOS to see |

## How to Run

```bash
cd examples/navigation-demo
bun install
bun run dev:ios
# or: bun run dev:android
# or: bun run dev:macos
```

This directory contains Vue source only. Copy it into a generated project with
the corresponding native host before opening Xcode or Android Studio.

## Key Concepts

### Router Setup

```typescript
import { createRouter } from '@thelacanians/vue-native-navigation'

const router = createRouter([
  { name: 'home', component: HomeView },
  { name: 'detail', component: DetailView },
  { name: 'settings', component: SettingsView },
])
```

### Navigation with Params

```typescript
const router = useRouter()

// Navigate with params
router.push('detail', { id: 42, name: 'John' })

// Go back
router.pop()

// Replace current screen
router.replace('home')
```

### Accessing Route Params

```typescript
const route = useRoute()

// Access params
const id = route.value.params.id
const name = route.value.params.name
```

### Navigation Guards

```typescript
router.beforeEach((to, from, next) => {
  console.log(`Navigating from ${from.name} to ${to.name}`)
  
  // Can prevent navigation
  if (to.name === 'admin' && !isLoggedIn) {
    next(false)
  } else {
    next()
  }
})
```

### Back Button Handling

```typescript
const { onBackPress } = useBackHandler()

onBackPress(() => {
  console.log('Back button pressed')
  // Return true to prevent default behavior
  return false
})
```

## File Structure

```
examples/navigation-demo/
├── app/
│   ├── main.ts
│   ├── App.vue
│   └── screens/
│       ├── HomeScreen.vue
│       ├── DetailScreen.vue
│       ├── ProfileScreen.vue
│       ├── SearchScreen.vue
│       └── SettingsScreen.vue
├── vite.config.ts
└── package.json
```

## Learn More

- [Navigation Guide](../../docs/src/navigation/README.md)
- [useRouter](../../docs/src/navigation/params.md)
- [Navigation Guards](../../docs/src/navigation/guards.md)
- [Screen Lifecycle](../../docs/src/navigation/screen-lifecycle.md)

## Try This

Experiment with:
1. Add tab navigation
2. Implement drawer navigation
3. Add deep linking
4. Implement nested navigation
5. Add transition animations
