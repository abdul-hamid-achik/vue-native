# VButton

A pressable container view. Maps to a `UIControl`-based view on iOS and a custom touch delegate on Android.

Unlike web buttons, `VButton` is a layout container -- place `VText` or other views inside it.

## Usage

```vue
<VButton
  :style="{ backgroundColor: '#007AFF', padding: 12, borderRadius: 8 }"
  :onPress="handlePress"
>
  <VText :style="{ color: '#fff', fontWeight: '600' }">Tap me</VText>
</VButton>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `style` | `StyleProp` | -- | Layout + appearance styles |
| `disabled` | `boolean` | `false` | Disable press interactions |
| `activeOpacity` | `number` | `0.7` | Opacity when the button is pressed (0.0 to 1.0) |
| `onPress` | `Function` | -- | Callback fired on tap |
| `onLongPress` | `Function` | -- | Callback fired on long press (~500ms) |
| `accessibilityLabel` | `string` | -- | Accessible description |
| `accessibilityRole` | `string` | -- | Accessibility role |
| `accessibilityHint` | `string` | -- | Additional accessibility context |
| `accessibilityState` | `object` | -- | Accessibility state (e.g. `{ disabled: true }`) |

::: warning
VButton uses **props** for press handlers (`:onPress`, `:onLongPress`), not Vue events (`@press`). This is because native press handling is passed directly to the native view factory.
:::

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const count = ref(0)
const submit = () => count.value++
</script>

<template>
  <VView :style="{ padding: 20, gap: 12 }">
    <VButton :style="styles.button" :onPress="submit">
      <VText :style="styles.label">Pressed {{ count }} times</VText>
    </VButton>

    <VButton :style="styles.button" :disabled="true">
      <VText :style="styles.label">Disabled</VText>
    </VButton>

    <VButton
      :style="styles.outline"
      :onPress="() => console.log('Long press supported')"
      :onLongPress="() => console.log('Long pressed!')"
    >
      <VText :style="styles.outlineLabel">Long press me</VText>
    </VButton>
  </VView>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

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
  outline: {
    borderWidth: 1,
    borderColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  outlineLabel: {
    color: '#007AFF',
    fontSize: 16,
    fontWeight: '600',
  },
})
</script>
```
