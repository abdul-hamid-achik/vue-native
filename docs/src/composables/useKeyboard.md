# useKeyboard

Provides reactive keyboard visibility state and programmatic keyboard control. Useful for adjusting layouts when the software keyboard appears or for dismissing the keyboard on demand.

## Usage

```vue
<script setup>
import { useKeyboard } from '@thelacanians/vue-native-runtime'

const { isVisible, height, dismiss } = useKeyboard()
</script>
```

## API

```ts
useKeyboard(): {
  isVisible: Ref<boolean>
  height: Ref<number>
  dismiss: () => Promise<void>
  getHeight: () => Promise<{ height: number; isVisible: boolean }>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `isVisible` | `Ref<boolean>` | Whether the keyboard is currently visible. Updated when `getHeight()` is called. |
| `height` | `Ref<number>` | The current keyboard height in points. `0` when the keyboard is hidden. Updated when `getHeight()` is called. |
| `dismiss` | `() => Promise<void>` | Dismiss the keyboard programmatically by resigning first responder. |
| `getHeight` | `() => Promise<{ height: number; isVisible: boolean }>` | Query the current keyboard height and visibility. Also updates the `isVisible` and `height` refs. |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `UIResponder.resignFirstResponder` to dismiss. Keyboard state queried via the Keyboard native module. |
| Android | Uses `InputMethodManager` to hide the keyboard. |

## Example

```vue
<script setup>
import { useKeyboard } from '@thelacanians/vue-native-runtime'

const { isVisible, height, dismiss, getHeight } = useKeyboard()

async function checkKeyboard() {
  await getHeight()
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VInput
      placeholder="Tap to open keyboard"
      :style="{ borderWidth: 1, borderColor: '#ccc', padding: 10 }"
    />

    <VText :style="{ marginTop: 10 }">
      Keyboard visible: {{ isVisible }}
    </VText>
    <VText>Keyboard height: {{ height }}</VText>

    <VButton :onPress="checkKeyboard"><VText>Check Keyboard</VText></VButton>
    <VButton :onPress="dismiss"><VText>Dismiss Keyboard</VText></VButton>
  </VView>
</template>
```

## Notes

- The `isVisible` and `height` refs are updated when you call `getHeight()`. They do not auto-update on keyboard show/hide events (poll with `getHeight()` when needed).
- Use the `VKeyboardAvoiding` component for automatic layout adjustment when the keyboard appears, rather than manually tracking keyboard height.
- `dismiss()` works by sending `resignFirstResponder` to the current first responder on iOS, and hiding the soft input on Android.
