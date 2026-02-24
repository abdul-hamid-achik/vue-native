# VActivityIndicator

A loading spinner component. Maps to `UIActivityIndicatorView` on iOS and a circular `ProgressBar` on Android.

## Usage

```vue
<VActivityIndicator :animating="isLoading" color="#007AFF" size="large" />
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `animating` | `boolean` | `true` | Whether the spinner is animating |
| `color` | `string` | system default | Spinner color (hex or named color) |
| `size` | `'small' \| 'medium' \| 'large'` | `'medium'` | Spinner size |
| `hidesWhenStopped` | `boolean` | `true` | Hide the indicator when `animating` is `false` |
| `style` | `StyleProp` | — | Layout + appearance styles |

## Events

VActivityIndicator does not emit any events.

## Example

```vue
<script setup>
import { ref } from 'vue'

const loading = ref(true)

function fetchData() {
  loading.value = true
  setTimeout(() => {
    loading.value = false
  }, 2000)
}
</script>

<template>
  <VView :style="styles.container">
    <VActivityIndicator
      :animating="loading"
      color="#007AFF"
      size="large"
    />
    <VButton :style="styles.button" :onPress="fetchData">
      <VText :style="styles.label">Reload</VText>
    </VButton>
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 20,
  },
  button: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  label: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
})
</script>
```

## Notes

- When `hidesWhenStopped` is `true` (the default), the indicator becomes invisible when `animating` is `false`. It still occupies layout space unless you conditionally render it with `v-if`.
- The `size` prop maps to `UIActivityIndicatorView.Style.medium` / `.large` on iOS. On Android, the circular `ProgressBar` widget is used.
