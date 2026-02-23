# Passing Params

## Passing params on navigation

```ts
router.push('profile', { userId: 123, username: 'alice' })
```

## Reading params in the destination screen

```vue
<script setup>
import { useRoute } from '@vue-native/navigation'

const route = useRoute()
const userId = route.params.userId     // 123
const username = route.params.username // 'alice'
</script>
```

`useRoute()` is reactive — if params change (e.g. via `router.replace`), the component re-renders.

## Typed params (TypeScript)

You can type your params with a generic:

```ts
const route = useRoute<{ userId: number; username: string }>()
```

## Passing complex objects

Params can be any serializable value:

```ts
router.push('checkout', {
  items: [{ id: 1, qty: 2 }, { id: 3, qty: 1 }],
  total: 49.99,
})
```
