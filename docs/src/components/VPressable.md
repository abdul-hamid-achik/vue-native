# VPressable

A generic pressable container component. Like `VButton` but without any default styling or built-in text label. Wraps any children in a touchable container with configurable press feedback.

On iOS this maps to a custom `TouchableView` (UIView subclass) with opacity animation. On Android this maps to a `TouchableView` (FlexboxLayout subclass).

## Usage

```vue
<VPressable
  :style="{ padding: 16 }"
  :onPress="handlePress"
  :activeOpacity="0.6"
>
  <VView :style="{ flexDirection: 'row', alignItems: 'center' }">
    <VImage :source="{ uri: iconUrl }" :style="{ width: 24, height: 24 }" />
    <VText :style="{ marginLeft: 8 }">Press me</VText>
  </VView>
</VPressable>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `style` | `StyleProp` | -- | Layout + appearance styles |
| `disabled` | `boolean` | `false` | Disable press interactions |
| `activeOpacity` | `number` | `0.7` | Opacity when pressed (0.0 to 1.0) |
| `onPress` | `Function` | -- | Callback fired on tap |
| `onPressIn` | `Function` | -- | Callback fired when the touch starts |
| `onPressOut` | `Function` | -- | Callback fired when the touch ends |
| `onLongPress` | `Function` | -- | Callback fired on long press (~500ms) |
| `accessibilityLabel` | `string` | -- | Accessible description |
| `accessibilityRole` | `string` | -- | Accessibility role |
| `accessibilityHint` | `string` | -- | Additional accessibility context |
| `accessibilityState` | `object` | -- | Accessibility state |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@press` | -- | Emitted on tap. Equivalent to the `onPress` prop. |
| `@press-in` | -- | Emitted when the touch starts. Equivalent to the `onPressIn` prop. |
| `@press-out` | -- | Emitted when the touch ends. Equivalent to the `onPressOut` prop. |
| `@long-press` | -- | Emitted on a long press (~500ms). Equivalent to the `onLongPress` prop. |

## VPressable vs VButton

| Feature | VButton | VPressable |
|---------|---------|------------|
| Press events | `onPress`, `onLongPress` | `onPress`, `onPressIn`, `onPressOut`, `onLongPress` |
| Press-in/out feedback | No | Yes |
| Styling | Same | Same |

Use `VPressable` when you need press-in/out events (e.g. for custom highlight animations) or when building custom interactive components.

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const isPressed = ref(false)
</script>

<template>
  <VPressable
    :style="{
      padding: 20,
      backgroundColor: isPressed ? '#e0e0e0' : '#f5f5f5',
      borderRadius: 12,
    }"
    :onPress="() => console.log('Pressed!')"
    :onPressIn="() => isPressed = true"
    :onPressOut="() => isPressed = false"
    :onLongPress="() => console.log('Long pressed!')"
  >
    <VText :style="{ fontSize: 16, fontWeight: '600' }">
      Custom Pressable
    </VText>
    <VText :style="{ fontSize: 14, color: '#666', marginTop: 4 }">
      With press-in/out visual feedback
    </VText>
  </VPressable>
</template>
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS      | Full (custom `TouchableView`, a `UIView` subclass, with opacity animation) |
| Android  | Full (`TouchableView`, a `FlexboxLayout` subclass) |
| macOS    | Full (custom `PressableView`, a `ClickableView`/`NSView` subclass) |

## Notes

- All press callbacks (`onPress`, `onPressIn`, `onPressOut`, `onLongPress`) are disabled when `disabled` is `true`.
- In templates, `@press="handler"` and `:onPress="handler"` both bind the native press handler (and likewise `@press-in`/`@press-out`/`@long-press` map to `onPressIn`/`onPressOut`/`onLongPress`). Render functions should pass the `onPress`, `onPressIn`, `onPressOut`, and `onLongPress` props.
