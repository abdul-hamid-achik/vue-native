# Passing Params

## Passing params on navigation

```ts
router.push('profile', { userId: 123, username: 'alice' })
```

## Reading params in the destination screen

`useRoute()` returns a `ComputedRef<RouteLocation>` -- access `.value` for the current route:

```vue
<script setup>
import { useRoute } from '@thelacanians/vue-native-navigation'

const route = useRoute()
// route.value.name    -> 'profile'
// route.value.params  -> { userId: 123, username: 'alice' }
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText>User: {{ route.value.params.username }}</VText>
    <VText>ID: {{ route.value.params.userId }}</VText>
  </VView>
</template>
```

`useRoute()` is reactive -- if params change (e.g. via `router.replace`), the component re-renders.

## Passing complex objects

Params can be any serializable value:

```ts
router.push('checkout', {
  items: [{ id: 1, qty: 2 }, { id: 3, qty: 1 }],
  total: 49.99,
})
```

## RouteLocation type

```ts
interface RouteLocation {
  name: string
  params: Record<string, any>
  options: RouteOptions
}
```
