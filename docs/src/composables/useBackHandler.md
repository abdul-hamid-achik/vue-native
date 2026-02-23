# useBackHandler

Intercept the hardware back button press on Android. On iOS this is a no-op (no hardware back button), but the event can still be dispatched programmatically.

## Usage

```vue
<script setup>
import { ref } from 'vue-native'
import { useBackHandler } from 'vue-native'

const hasUnsavedChanges = ref(false)

useBackHandler(() => {
  if (hasUnsavedChanges.value) {
    // Show discard dialog, prevent default back navigation
    return true
  }
  // Allow default back navigation
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
| `handler` | `() => boolean` | Called on hardware back press. Return `true` to prevent default behavior, `false` to allow it. |

## Platform Support

| Platform | Support |
|----------|---------|
| Android | Hardware back button |
| iOS | No-op (no hardware back button) |

## Notes

- The handler is automatically registered on `onMounted` and cleaned up on `onUnmounted`.
- Only the most recently registered handler is active — if multiple components register handlers, only the one currently mounted and registered last will fire.
- Useful for preventing accidental navigation when the user has unsaved changes, or for closing modals/drawers before navigating back.
