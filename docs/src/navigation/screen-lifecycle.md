# Screen Lifecycle

Vue Native provides two lifecycle hooks for responding to screen visibility changes in a stack navigator: `onScreenFocus` and `onScreenBlur`. These fire when a screen becomes (or stops being) the topmost visible route.

## Why Screen Lifecycle?

In a stack navigator, screens lower in the stack stay mounted even when they're not visible. Standard Vue lifecycle hooks (`onMounted`, `onUnmounted`) don't help here — the component is already mounted, it just isn't the active screen.

Use screen lifecycle hooks to:

- **Refresh data** when the user returns to a screen
- **Start/stop timers** (polling, animations) based on visibility
- **Pause media** when navigating away
- **Track screen views** for analytics

## onScreenFocus

Called when the screen becomes the top route in the stack. Fires immediately if the screen is already focused when the hook is registered.

```ts
import { onScreenFocus } from '@thelacanians/vue-native-navigation'
```

```vue
<script setup>
import { ref } from 'vue'
import { onScreenFocus } from '@thelacanians/vue-native-navigation'

const messages = ref([])

onScreenFocus(() => {
  // Refresh data every time the user returns to this screen
  fetchMessages().then((data) => {
    messages.value = data
  })
})
</script>

<template>
  <VView :style="{ flex: 1 }">
    <VList :data="messages" :style="{ flex: 1 }">
      <template #item="{ item }">
        <VText :style="{ padding: 12 }">{{ item.text }}</VText>
      </template>
    </VList>
  </VView>
</template>
```

## onScreenBlur

Called when the screen is no longer the top route — either because a new screen was pushed on top, or the user navigated to a different tab.

```ts
import { onScreenBlur } from '@thelacanians/vue-native-navigation'
```

```vue
<script setup>
import { onScreenFocus, onScreenBlur } from '@thelacanians/vue-native-navigation'
import { useAudio } from '@thelacanians/vue-native-runtime'

const { play, pause } = useAudio()

onScreenFocus(() => {
  // Resume playback when screen is visible
  play('https://example.com/background-music.mp3')
})

onScreenBlur(() => {
  // Pause when navigating away
  pause()
})
</script>
```

## API

### onScreenFocus

```ts
onScreenFocus(callback: () => void): void
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `callback` | `() => void` | Called each time the screen becomes the topmost route |

### onScreenBlur

```ts
onScreenBlur(callback: () => void): void
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `callback` | `() => void` | Called each time the screen is no longer the topmost route |

## How It Works

Both hooks use `useRouter()` internally and watch `router.currentRoute`. Each screen rendered by `RouterView` is given a unique entry key. The hooks compare the current route's key against the screen's key to determine focus state.

```
Screen A (focused) → push Screen B → Screen A blurs, Screen B focuses
                   → pop Screen B  → Screen B unmounts, Screen A focuses
```

- `onScreenFocus` fires when the current route key **matches** the screen's key (and it wasn't already focused).
- `onScreenBlur` fires when the current route key **stops matching** the screen's key (and it was previously focused).
- Both watchers are created with `{ immediate: true }`, so `onScreenFocus` fires right away if the screen is already the top route.
- Watchers are automatically cleaned up on `onUnmounted`.

## Requirements

Both hooks must be called inside a component rendered by `RouterView`. They rely on the route context that `RouterView` provides. Calling them outside a routed screen will not work.

## Common Patterns

### Polling with Start/Stop

```vue
<script setup>
import { ref } from 'vue'
import { onScreenFocus, onScreenBlur } from '@thelacanians/vue-native-navigation'

const data = ref(null)
let pollTimer = null

function startPolling() {
  fetchData().then((d) => (data.value = d))
  pollTimer = setInterval(() => {
    fetchData().then((d) => (data.value = d))
  }, 5000)
}

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer)
    pollTimer = null
  }
}

onScreenFocus(startPolling)
onScreenBlur(stopPolling)
</script>
```

### Analytics Screen Tracking

```vue
<script setup>
import { onScreenFocus } from '@thelacanians/vue-native-navigation'
import { useRoute } from '@thelacanians/vue-native-navigation'

const route = useRoute()

onScreenFocus(() => {
  analytics.track('screen_view', {
    screen: route.name,
    params: route.params,
    timestamp: Date.now(),
  })
})
</script>
```

### Form Auto-Save on Blur

```vue
<script setup>
import { ref } from 'vue'
import { onScreenBlur } from '@thelacanians/vue-native-navigation'

const draft = ref('')

onScreenBlur(() => {
  if (draft.value.trim()) {
    saveDraft(draft.value)
  }
})
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VInput
      :value="draft"
      :onChangeText="(t) => (draft = t)"
      placeholder="Write something..."
      multiline
      :style="{
        flex: 1,
        borderWidth: 1,
        borderColor: '#ddd',
        borderRadius: 8,
        padding: 12,
        fontSize: 16,
        textAlignVertical: 'top',
      }"
    />
  </VView>
</template>
```

### Combining Focus and Blur

```vue
<script setup>
import { ref } from 'vue'
import {
  onScreenFocus,
  onScreenBlur,
} from '@thelacanians/vue-native-navigation'
import { useAnimation } from '@thelacanians/vue-native-runtime'

const { start, stop } = useAnimation()
const focusCount = ref(0)

onScreenFocus(() => {
  focusCount.value++
  start() // resume animations
  console.log(`Screen focused (visit #${focusCount.value})`)
})

onScreenBlur(() => {
  stop() // pause animations to save resources
  console.log('Screen blurred')
})
</script>
```

## Comparison with Vue Lifecycle

| Hook | When It Fires | Fires Multiple Times? |
|------|---------------|----------------------|
| `onMounted` | Component is first inserted into the DOM tree | No — once per mount |
| `onUnmounted` | Component is removed from the DOM tree | No — once per unmount |
| `onScreenFocus` | Screen becomes the topmost route | Yes — every time |
| `onScreenBlur` | Screen is no longer the topmost route | Yes — every time |

In a stack navigator with `unmountInactiveScreens: false` (the default), a screen at the bottom of the stack stays mounted but is not focused. `onScreenFocus` / `onScreenBlur` capture this distinction.

## See also

- [Navigation guards](./guards.md)
- [Stack navigation](./stack.md)
- [Navigation overview](./README.md)
