# Chat

A chat interface demonstrating real-time messaging, lists, and input handling.

> **Requires a native host.** This directory ships Vue source and build config
> only — there is no `ios/`, `android/`, or `macos/` app shell here. `bun run
> dev:ios`, `dev:android` and `dev:macos` build the JS bundle but have nothing
> to run it in. To see this app on a device or simulator:
>
> ```bash
> bunx vue-native create my-app   # scaffolds iOS + Android hosts
> ```
>
> Then copy `app/`, `vite.config.ts` and `env.d.ts` from this example over the
> scaffold's equivalents, run `bun run build` here, and open the generated
> project in Xcode or Android Studio. `vue-native create` does not scaffold a
> macOS shell yet.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput, VScrollView, VKeyboardAvoiding, VSafeArea
- **Composables:** `useWebSocket`
- **Patterns:**
  - Real-time messaging over a WebSocket, with connection status
  - Keyboard-avoiding input bar
  - Auto-scrolling transcript in a `VScrollView`
  - Sender / receiver message bubble styling

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
