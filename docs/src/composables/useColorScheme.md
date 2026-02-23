# useColorScheme

Reactive dark mode detection. Tracks the system color scheme and updates automatically when the user switches between light and dark mode.

## Usage

```vue
<script setup>
import { useColorScheme } from '@thelacanians/vue-native-runtime'

const { colorScheme, isDark } = useColorScheme()
</script>

<template>
  <VView :style="{ backgroundColor: isDark ? '#000' : '#FFF', flex: 1 }">
    <VText :style="{ color: isDark ? '#FFF' : '#000' }">
      Current theme: {{ colorScheme }}
    </VText>
  </VView>
</template>
```

## API

```ts
useColorScheme(): { colorScheme: Ref<ColorScheme>, isDark: Ref<boolean> }
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `colorScheme` | `Ref<ColorScheme>` | The current system color scheme: `'light'` or `'dark'`. Defaults to `'light'`. |
| `isDark` | `Ref<boolean>` | Convenience boolean — `true` when `colorScheme` is `'dark'`. |

### Types

```ts
type ColorScheme = 'light' | 'dark'
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Observes `UITraitCollection.userInterfaceStyle` changes. |
| Android | Observes `Configuration.uiMode` changes. |

## Example

```vue
<script setup>
import { computed } from 'vue'
import { useColorScheme } from '@thelacanians/vue-native-runtime'

const { isDark } = useColorScheme()

const theme = computed(() => ({
  bg: isDark.value ? '#1a1a2e' : '#ffffff',
  text: isDark.value ? '#e0e0e0' : '#1a1a1a',
  card: isDark.value ? '#2d2d44' : '#f5f5f5',
}))
</script>

<template>
  <VView :style="{ backgroundColor: theme.bg, flex: 1, padding: 20 }">
    <VText :style="{ color: theme.text, fontSize: 24, fontWeight: 'bold' }">
      Settings
    </VText>
    <VView :style="{ backgroundColor: theme.card, padding: 16, borderRadius: 12, marginTop: 16 }">
      <VText :style="{ color: theme.text }">
        Theme: {{ isDark ? 'Dark' : 'Light' }}
      </VText>
    </VView>
  </VView>
</template>
```

## Notes

- The composable subscribes to native `colorScheme:change` events and automatically cleans up on `onUnmounted`.
- `colorScheme` defaults to `'light'` before the first native event fires. If you need the accurate initial value immediately, the native side should dispatch the current scheme on startup.
- Use `isDark` for simple conditional styling. Use `colorScheme` when you need the raw value (e.g., for a theme switcher UI).
