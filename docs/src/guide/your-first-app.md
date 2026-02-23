# Your First App

## Write a component

Vue Native components are standard Vue 3 SFCs. Use the built-in native components instead of HTML elements:

```vue
<script setup lang="ts">
import { ref } from '@thelacanians/vue-native-runtime'

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
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  title: { fontSize: 24, marginBottom: 20 },
  button: { backgroundColor: '#007AFF', paddingHorizontal: 24, paddingVertical: 12, borderRadius: 8 },
})
</script>
```

## Entry point

```ts
// app/main.ts
import { createApp } from '@thelacanians/vue-native-runtime'
import App from './App.vue'

createApp(App).start()
```

## Start development

```bash
bun run dev
```

This starts Vite in watch mode. Open `ios/` in Xcode (or `android/` in Android Studio) and run on a simulator or device.

Changes to your `.vue` files are hot-reloaded instantly without restarting the app.
