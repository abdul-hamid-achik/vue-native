# Navigation

Vue Native provides stack-based navigation via `@vue-native/navigation`.

## Install

Navigation is included in the default project scaffold. To add it manually:

```bash
bun add @vue-native/navigation
```

## Quick start

```ts
// app/main.ts
import { createApp } from '@vue-native/runtime'
import { createRouter } from '@vue-native/navigation'
import App from './App.vue'
import HomeView from './views/HomeView.vue'
import DetailView from './views/DetailView.vue'

const { router } = createRouter([
  { name: 'home', component: HomeView },
  { name: 'detail', component: DetailView },
])

createApp(App).use(router).mount('#app')
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
import { useRouter } from '@vue-native/navigation'
const router = useRouter()
</script>

<template>
  <VView style="flex: 1; padding: 20">
    <VButton @press="router.push('detail', { id: 1 })">
      <VText>Open Detail</VText>
    </VButton>
  </VView>
</template>
```

## See also

- [Stack navigation](./stack.md)
- [Passing params](./params.md)
