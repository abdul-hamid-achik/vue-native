# useBackHandler

Intercept the hardware back button press on Android. On iOS this is a no-op (no hardware back button), but the event can still be dispatched programmatically.

## Usage

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useBackHandler } from '@thelacanians/vue-native-runtime'

const hasUnsavedChanges = ref(false)

useBackHandler(() => {
  if (hasUnsavedChanges.value) {
    // Show discard dialog; do not call BackHandler.exitApp
    return true
  }
  // This listener did not handle the press — useBackHandler calls exitApp
  return false
})
</script>
```

## API

```ts
useBackHandler(handler: () => boolean): void
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `handler` | `() => boolean` | Called on hardware back press. Return `true` if this listener handled the press (`useBackHandler` will not call `exitApp`). Return `false` to let this composable exit the app. |

## Platform Support

| Platform | Support |
|----------|---------|
| Android | Hardware back button |
| iOS | No-op (no hardware back button) |

## Notes

- The handler is automatically registered on `onMounted` and cleaned up on `onUnmounted`.
- Returning `true` only skips `exitApp` from **this** composable. The bridge still delivers `hardware:backPress` to every subscriber, including a router created with `handleBackButton: true`. Do not combine the two on the same screen.
- If no handler is registered and `handleBackButton` is off, Android finishes the current Activity.
- If multiple components register handlers, each mounted handler receives the event. Prefer one owner for modal or navigation back behavior.
