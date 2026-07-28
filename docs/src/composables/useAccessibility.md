# useAccessibility

Screen-reader announcements and accessibility focus management. Wraps the native
`Accessibility` module (VoiceOver on iOS/macOS, TalkBack on Android).

## API

```ts
const { announce, setFocus } = useAccessibility()
```

| Method | Signature | Description |
|--------|-----------|-------------|
| `announce` | `(message: string) => void` | Make the screen reader speak a message **without** moving focus. Use for status updates and live-region-style notifications (WCAG 4.1.3). |
| `setFocus` | `(target: number \| Ref \| NativeNode) => void` | Move accessibility focus to a view. Use after opening a modal/dialog or revealing new content (WCAG 2.4.3). |

## Example

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { useAccessibility, VButton, VText } from '@thelacanians/vue-native-runtime'

const { announce, setFocus } = useAccessibility()
const dialogRef = ref()
const count = ref(0)

function addToCart() {
  count.value++
  // Announce the change without moving focus.
  announce(`${count.value} item${count.value === 1 ? '' : 's'} in your cart`)
}

function openDialog() {
  // Move VoiceOver/TalkBack focus into the dialog.
  setFocus(dialogRef)
}
</script>

<template>
  <VButton title="Add to cart" @press="addToCart" />
  <VText>{{ count }} in cart</VText>
</template>
```

## Notes

- `announce` is fire-and-forget; it does not interrupt the user's current focus.
- `setFocus` accepts a numeric node id, a template ref, or a `NativeNode`.
- Announcements and focus changes are no-ops if the platform has no active screen reader.
