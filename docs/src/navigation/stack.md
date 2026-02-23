# Stack Navigation

The stack navigator maintains a history of screens. Navigating to a new screen pushes it onto the stack; going back pops the top screen.

## API

### `router.push(name, params?)`

Navigate to a screen, adding it to the stack.

```ts
router.push('detail', { id: 42 })
```

### `router.pop()`

Remove the top screen and return to the previous one.

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

## Transitions

Screen transitions use a horizontal slide animation (`translateX`). The new screen slides in from the right; popping slides back to the left.

## RouterView

`<RouterView />` renders the active screen. Place it in your root `App.vue`:

```vue
<template>
  <RouterView />
</template>
```
