# Stack Navigation

The stack navigator maintains a history of screens. Navigating to a new screen pushes it onto the stack; going back pops the top screen.

## API

### `router.push(name, params?)`

Navigate to a screen, adding it to the stack. Alias: `router.navigate()`.

```ts
router.push('detail', { id: 42 })
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

All screens in the stack are mounted simultaneously (so back navigation is instant -- no remounting). Only the top screen is visible.
