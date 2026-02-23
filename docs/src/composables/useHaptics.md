# useHaptics

Haptic feedback for touch interactions. Provides three types of tactile feedback: impact (for button taps and collisions), notification (for success/warning/error outcomes), and selection (for picker changes).

## Usage

```vue
<script setup>
import { useHaptics } from '@thelacanians/vue-native-runtime'

const { vibrate, notificationFeedback, selectionChanged } = useHaptics()
</script>

<template>
  <VButton title="Tap me" :onPress="() => vibrate('medium')" />
</template>
```

## API

```ts
useHaptics(): {
  vibrate: (style?: ImpactStyle) => Promise<void>
  notificationFeedback: (type?: NotificationType) => Promise<void>
  selectionChanged: () => Promise<void>
}
```

### Return Value

| Method | Signature | Description |
|--------|-----------|-------------|
| `vibrate` | `(style?: ImpactStyle) => Promise<void>` | Trigger impact feedback. Defaults to `'medium'`. |
| `notificationFeedback` | `(type?: NotificationType) => Promise<void>` | Trigger notification feedback. Defaults to `'success'`. |
| `selectionChanged` | `() => Promise<void>` | Trigger selection feedback, typically used when a user scrolls through a picker. |

### Types

```ts
type ImpactStyle = 'light' | 'medium' | 'heavy' | 'rigid' | 'soft'

type NotificationType = 'success' | 'warning' | 'error'
```

#### Impact Styles

| Style | Use Case |
|-------|----------|
| `'light'` | Small, subtle interactions (toggle switch) |
| `'medium'` | Standard button taps |
| `'heavy'` | Significant actions (drag drop, force press) |
| `'rigid'` | Sharp, precise feedback |
| `'soft'` | Gentle, muted feedback |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`, and `UISelectionFeedbackGenerator`. |
| Android | Uses `HapticFeedbackConstants` and `Vibrator` service. |

## Example

```vue
<script setup>
import { useHaptics } from '@thelacanians/vue-native-runtime'

const { vibrate, notificationFeedback, selectionChanged } = useHaptics()

function onAddToCart() {
  vibrate('medium')
}

function onPaymentSuccess() {
  notificationFeedback('success')
}

function onPaymentError() {
  notificationFeedback('error')
}
</script>

<template>
  <VView :style="{ padding: 20, gap: 12 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold' }">Haptics Demo</VText>

    <VButton title="Impact: Light" :onPress="() => vibrate('light')" />
    <VButton title="Impact: Medium" :onPress="() => vibrate('medium')" />
    <VButton title="Impact: Heavy" :onPress="() => vibrate('heavy')" />
    <VButton title="Notify: Success" :onPress="() => notificationFeedback('success')" />
    <VButton title="Notify: Warning" :onPress="() => notificationFeedback('warning')" />
    <VButton title="Notify: Error" :onPress="() => notificationFeedback('error')" />
    <VButton title="Selection" :onPress="selectionChanged" />
  </VView>
</template>
```

## Notes

- This composable has no reactive state and no cleanup. All methods return Promises that resolve once the native haptic engine fires.
- Haptic feedback is a no-op on devices without a haptic engine (e.g., simulator, older iPads).
- Use haptics sparingly — overuse diminishes their impact and can annoy users. Apple's Human Interface Guidelines recommend haptics only for meaningful interactions.
