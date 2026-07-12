# Chat

A chat interface demonstrating real-time messaging, lists, and input handling.

## What It Demonstrates

- **Components:** VList, VInput, VButton, VView, VText, VImage
- **Composables:** `useWebSocket` for real-time, `useKeyboard` for keyboard handling
- **Patterns:**
  - Real-time messaging
  - Auto-scroll to bottom
  - Keyboard handling
  - Message bubbles

## Key Features

- Message list
- Input with send button
- Auto-scroll on new message
- Timestamp display
- Sender/receiver styling

## How to Run

```bash
cd examples/chat
bun install
bun run dev:ios
# or: bun run dev:android
# or: bun run dev:macos
```

This directory contains Vue source only. Copy it into a generated project that
has the corresponding native host before launching it.

## Key Concepts

### WebSocket Integration

```typescript
import { ref, watch } from 'vue'
import { useWebSocket } from '@thelacanians/vue-native-runtime'

const messages = ref<string[]>([])
const { lastMessage } = useWebSocket('wss://chat.example.com')

watch(lastMessage, (data) => {
  if (data !== null) messages.value.push(data)
})
```

### Auto-Scroll

```typescript
const listRef = ref(null)

watch(() => messages.value.length, () => {
  listRef.value?.scrollToEnd({ animated: true })
})
```

## Learn More

- [useWebSocket](../../docs/src/composables/useWebSocket.md)
- [useKeyboard](../../docs/src/composables/useKeyboard.md)
- [VList Component](../../docs/src/components/VList.md)
