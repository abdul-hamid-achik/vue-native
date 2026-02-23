# VProgressBar

A horizontal progress indicator bar. Maps to `UIProgressView` on iOS and a horizontal `ProgressBar` on Android.

## Usage

```vue
<VProgressBar :progress="0.75" progressTintColor="#007AFF" />
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `progress` | `number` | `0` | Progress value from `0` to `1` |
| `progressTintColor` | `string` | system default | Color of the filled portion |
| `trackTintColor` | `string` | system default | Color of the unfilled track |
| `animated` | `boolean` | `true` | Animate progress changes |
| `style` | `StyleProp` | — | Layout + appearance styles |

## Events

VProgressBar does not emit any events.

## Example

```vue
<script setup>
import { ref, onMounted } from 'vue'

const progress = ref(0)

onMounted(() => {
  const interval = setInterval(() => {
    progress.value += 0.1
    if (progress.value >= 1) clearInterval(interval)
  }, 500)
})
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.label">Downloading... {{ Math.round(progress * 100) }}%</VText>
    <VProgressBar
      :progress="progress"
      progressTintColor="#34C759"
      trackTintColor="#E5E5EA"
      :style="styles.bar"
    />
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    padding: 24,
    gap: 12,
  },
  label: {
    fontSize: 16,
    color: '#333',
  },
  bar: {
    height: 8,
  },
})
</script>
```

## Notes

- The `progress` value is clamped between `0` and `1` on the native side.
- On iOS, `UIProgressView` uses a thin default height. Use the `style` prop to adjust height if needed.
