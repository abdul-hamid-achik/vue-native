# Stack Navigation

The stack navigator maintains a history of screens. Navigating to a new screen pushes it onto the stack; going back pops the top screen.

## API

### `router.push(name, params?, options?)`

Navigate to a screen, adding it to the stack. Alias: `router.navigate()`.

```ts
router.push('detail', { id: 42 })
```

#### NavigateOptions

Pass an options object as the third argument to customize the navigation:

```ts
interface NavigateOptions {
  sharedElements?: string[]
}
```

| Property | Type | Description |
|----------|------|-------------|
| `sharedElements` | `string[]` | Shared element IDs to animate between source and destination screens. |

```ts
// Navigate with shared element transition
router.push('detail', { id: 42 }, {
  sharedElements: ['hero-image', 'title-text'],
})
```

### `router.pop()`

Remove the top screen and return to the previous one. Alias: `router.goBack()`.

```ts
router.pop()
```

### `router.replace(name, params?)`

Navigate to a screen, replacing the current one (the current screen is removed from history).

```ts
router.replace('home')
```

### `router.reset(name, params?)`

Clear the entire stack and navigate to the given screen.

```ts
router.reset('home')
```

### `router.canGoBack`

A reactive `ComputedRef<boolean>` that is `true` when there is a previous route to go back to.

```vue
<script setup>
import { useRouter } from '@thelacanians/vue-native-navigation'
const router = useRouter()
</script>

<template>
  <VButton v-if="router.canGoBack.value" :onPress="() => router.pop()">
    <VText>Go Back</VText>
  </VButton>
</template>
```

## Transitions

Screen transitions use a horizontal slide animation (`translateX`). The new screen slides in from the right; popping slides back to the left. Non-top screens are hidden with `opacity: 0` to prevent touch events from reaching them.

## RouterView

`<RouterView />` renders the active screen. Place it in your root `App.vue`:

```vue
<template>
  <RouterView />
</template>
```

By default, all screens in the stack are mounted simultaneously (so back navigation is instant -- no remounting). Only the top screen is visible.

## Unmounting Inactive Screens

For apps with many screens, keeping all of them mounted can use significant memory. Enable `unmountInactiveScreens` to only mount the active screen and the one behind it (for back animation):

```ts
const router = createRouter({
  routes: [
    { name: 'home', component: Home },
    { name: 'detail', component: Detail },
    { name: 'settings', component: Settings },
  ],
  unmountInactiveScreens: true,
})
```

When enabled, navigating from `home → detail → settings` will unmount the `home` screen. Going back from `settings` to `detail` will re-mount `detail` fresh. This trades navigation speed for lower memory usage.

::: tip
`unmountInactiveScreens` defaults to `false` for backward compatibility. Enable it in memory-constrained apps or when screens hold large resources (images, video, maps).
:::

## Back Navigation

Vue Native does **not** provide an automatic back gesture. The iOS swipe-from-edge gesture is **not currently supported** (there is no interactive pop transition), and on Android the hardware back button/gesture does **nothing** by default. You drive back navigation yourself with one of:

- The router's `handleBackButton` option (recommended for the Android hardware back button)
- A back button you render in your header, e.g. `<VButton @back="router.pop()">` or any control wired to `router.pop()`
- The [`useBackHandler`](/composables/useBackHandler.md) composable (for custom back behavior)
- A programmatic `router.pop()` / `router.goBack()` call

### Recommended: `handleBackButton`

Pass `handleBackButton: true` to `createRouter` and the router handles the
Android hardware back button/gesture for you: it pops the stack when it can go
back, and exits the app (`BackHandler.exitApp`) on the root screen. It defaults
to `false`.

```ts
import { createRouter } from '@thelacanians/vue-native-navigation'
import Home from './screens/Home.vue'
import Detail from './screens/Detail.vue'

const router = createRouter({
  routes: [
    { name: 'home', component: Home },
    { name: 'detail', component: Detail },
  ],
  handleBackButton: true,
})
```

::: warning
When `handleBackButton` is enabled, do **not** also register `useBackHandler`
for the same screen — both would react to the same back press. Use one or the
other.
:::

### Custom back behavior: `useBackHandler`

When you need logic beyond "pop or exit" (confirm dialogs, dismissing an overlay
first, etc.), wire up the hardware back button yourself with `useBackHandler`:

```vue
<script setup>
import { useRouter } from '@thelacanians/vue-native-navigation'
import { useBackHandler } from '@thelacanians/vue-native-runtime'

const router = useRouter()

useBackHandler(() => {
  if (router.canGoBack.value) {
    router.pop()
    return true // handled
  }
  return false // let the system handle it (exit app)
})
</script>
```

::: tip
Add `useBackHandler` in your root `App.vue` or in each screen that needs custom back behavior. Return `true` to consume the event, or `false` to let the system handle it (which typically exits the app on the root screen).
:::
