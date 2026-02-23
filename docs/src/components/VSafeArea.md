# VSafeArea

A container that automatically applies safe area insets as padding. Maps to a custom `SafeAreaView` (UIView subclass) on iOS and a `FlexboxLayout` with window insets listener on Android.

Use `VSafeArea` to keep your content clear of the device notch, status bar, home indicator, and rounded corners.

## Usage

```vue
<template>
  <VSafeArea :style="{ flex: 1, backgroundColor: '#fff' }">
    <VText>This content avoids the notch and home indicator.</VText>
  </VSafeArea>
</template>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `style` | `Object` | `{}` | Layout + appearance styles |

## Example

```vue
<script setup>
import { ref } from 'vue'

const items = ref(['Home', 'Search', 'Profile'])
</script>

<template>
  <VSafeArea :style="styles.container">
    <VText :style="styles.header">My App</VText>
    <VView v-for="item in items" :key="item" :style="styles.row">
      <VText>{{ item }}</VText>
    </VView>
  </VSafeArea>
</template>

<script>
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  header: {
    fontSize: 24,
    fontWeight: '700',
    padding: 16,
  },
  row: {
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
})
</script>
```

## How It Works

On iOS, `VSafeArea` reads `safeAreaInsets` from the system and applies them as Yoga padding (top, bottom, left, right). The insets update automatically on rotation or when the view moves to a new window.

On Android, it uses `WindowInsets` listeners to read system bar insets and applies them as view padding.

::: tip
Wrap your root screen content in `VSafeArea` so text and interactive elements never overlap with system UI.
:::
