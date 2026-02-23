# VSlider

A slider control for selecting a value from a continuous range. Maps to `UISlider` on iOS and `SeekBar` on Android. Supports `v-model` for two-way binding.

## Usage

```vue
<VSlider v-model="volume" :min="0" :max="100" />
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `modelValue` | `number` | `0` | The current value (use with `v-model`) |
| `min` | `number` | `0` | Minimum value |
| `max` | `number` | `1` | Maximum value |
| `style` | `Object` | `{}` | Layout styles |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@update:modelValue` | `number` | Emitted on value change (used by `v-model`) |
| `@change` | `number` | Emitted on value change with the new value |

## Example

```vue
<script setup>
import { ref } from 'vue'

const brightness = ref(0.5)
const volume = ref(0.8)
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.label">Brightness: {{ Math.round(brightness * 100) }}%</VText>
    <VSlider v-model="brightness" :min="0" :max="1" :style="styles.slider" />

    <VText :style="styles.label">Volume: {{ Math.round(volume * 100) }}%</VText>
    <VSlider v-model="volume" :min="0" :max="1" :style="styles.slider" />
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 24,
  },
  label: {
    fontSize: 16,
    marginBottom: 8,
  },
  slider: {
    marginBottom: 24,
  },
})
</script>
```

::: tip
The default range is `0` to `1`. For integer ranges (e.g., 0--100), set `:min="0"` and `:max="100"`.
:::
