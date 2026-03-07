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
bun vue-native dev
```

## Key Concepts

### WebSocket Integration

```typescript
const { send, onMessage } = useWebSocket('wss://chat.example.com')

onMessage((data) => {
  messages.value.push(data)
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
