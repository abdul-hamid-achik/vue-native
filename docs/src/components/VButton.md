# VButton

A pressable container view. Maps to a `UIControl`-based view on iOS and a custom touch delegate on Android.

Unlike web buttons, `VButton` is a layout container — place `VText` or other views inside it.

## Usage

```vue
<VButton
  :style="{ backgroundColor: '#007AFF', padding: 12, borderRadius: 8 }"
  @press="handlePress"
>
  <VText :style="{ color: '#fff', fontWeight: '600' }">Tap me</VText>
</VButton>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `style` | `StyleProp` | — | Layout + appearance styles |
| `disabled` | `boolean` | `false` | Disable press interactions |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@press` | `{ x, y }` | Tap / click |
| `@longPress` | `{ x, y }` | Long press (500 ms) |

## Example

```vue
<script setup>
const submit = () => console.log('Submitted!')
</script>

<template>
  <VButton :style="styles.button" @press="submit">
    <VText :style="styles.label">Submit</VText>
  </VButton>
</template>

<script>
import { createStyleSheet } from '@vue-native/runtime'

const styles = createStyleSheet({
  button: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  label: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
})
</script>
```
