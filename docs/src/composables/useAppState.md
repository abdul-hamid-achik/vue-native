# useAppState

Reactive app lifecycle state. Tracks whether the app is in the foreground (`active`), transitioning (`inactive`), or in the background. Useful for pausing work, saving data, or refreshing content when the app returns to the foreground.

## Usage

```vue
<script setup>
import { useAppState } from '@thelacanians/vue-native-runtime'

const { state } = useAppState()
</script>

<template>
  <VView>
    <VText>App is {{ state }}</VText>
  </VView>
</template>
```

## API

```ts
useAppState(): { state: Ref<AppStateStatus> }
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `state` | `Ref<AppStateStatus>` | The current app lifecycle state. |

### Types

```ts
type AppStateStatus = 'active' | 'inactive' | 'background' | 'unknown'
```

| Value | Meaning |
|-------|---------|
| `'active'` | The app is in the foreground and receiving events. |
| `'inactive'` | The app is in the foreground but not receiving events (e.g., during a phone call overlay or notification center pull-down). |
| `'background'` | The app is in the background. |
| `'unknown'` | Initial state before the first native check resolves. |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Observes `UIApplication.didBecomeActiveNotification`, `willResignActiveNotification`, and `didEnterBackgroundNotification`. |
| Android | Observes `Activity` lifecycle callbacks via `ProcessLifecycleOwner`. |

## Example

```vue
<script setup>
import { watch } from 'vue'
import { useAppState } from '@thelacanians/vue-native-runtime'
import { useAsyncStorage } from '@thelacanians/vue-native-runtime'

const { state } = useAppState()
const storage = useAsyncStorage()

// Auto-save when app goes to background
watch(state, async (newState) => {
  if (newState === 'background') {
    await storage.setItem('lastSaved', Date.now().toString())
    console.log('Data saved before backgrounding')
  }
  if (newState === 'active') {
    console.log('App returned to foreground')
  }
})
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold' }">
      App State Demo
    </VText>
    <VText>Current state: {{ state }}</VText>
  </VView>
</template>
```

## Notes

- The composable fetches the initial state from the native module and then subscribes to real-time lifecycle events.
- The event listener is automatically cleaned up on `onUnmounted`.
- On iOS, `inactive` fires briefly during transitions (e.g., pulling down the notification center or switching apps). On Android, the equivalent state depends on the activity lifecycle.
