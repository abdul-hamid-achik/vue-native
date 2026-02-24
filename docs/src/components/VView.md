# VView

A container view. The basic building block of every Vue Native layout.

Equivalent to `<div>` in web, `UIView` on iOS, `FlexboxLayout` on Android.

## Usage

```vue
<VView :style="{ flex: 1, padding: 16, backgroundColor: '#fff' }">
  <VText>Hello</VText>
</VView>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `style` | `StyleProp` | -- | Flexbox layout + appearance styles |
| `testID` | `string` | -- | Test identifier for end-to-end testing |
| `accessibilityLabel` | `string` | -- | Accessible description |
| `accessibilityRole` | `string` | -- | Accessibility role (e.g. `'button'`, `'header'`) |
| `accessibilityHint` | `string` | -- | Additional accessibility context |
| `accessibilityState` | `object` | -- | Accessibility state (e.g. `{ disabled: true }`) |

## Events

VView does not emit any events. For pressable containers, use [VButton](./VButton.md) or [VPressable](./VPressable.md).

## Flexbox

`VView` supports all Flexbox layout properties. See [Styling](../guide/styling.md) for the full list.

```vue
<VView :style="{
  flex: 1,
  flexDirection: 'row',
  alignItems: 'center',
  justifyContent: 'space-between',
  padding: 16,
  gap: 8,
}">
  <VText>Left</VText>
  <VText>Right</VText>
</VView>
```

## Example

```vue
<script setup>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  card: {
    backgroundColor: '#fff',
    padding: 16,
    borderRadius: 12,
    marginBottom: 12,
  },
})
</script>

<template>
  <VView :style="styles.container">
    <VView :style="styles.card">
      <VText :style="{ fontSize: 18, fontWeight: '600' }">Card Title</VText>
      <VText :style="{ color: '#666', marginTop: 4 }">Card description goes here.</VText>
    </VView>
    <VView :style="styles.card">
      <VText :style="{ fontSize: 18, fontWeight: '600' }">Another Card</VText>
      <VText :style="{ color: '#666', marginTop: 4 }">More content.</VText>
    </VView>
  </VView>
</template>
```
