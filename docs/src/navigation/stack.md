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

## Android Back Button

On iOS, the swipe-from-edge gesture automatically navigates back. On Android, the hardware back button/gesture does **nothing** by default -- you must handle it explicitly with `useBackHandler`:

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
