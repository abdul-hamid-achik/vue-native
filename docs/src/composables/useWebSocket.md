# useWebSocket

Reactive WebSocket connection. Manages a WebSocket connection with automatic reconnection support, reactive status tracking, and convenient message handling. Automatically cleans up the connection when the component unmounts.

## Usage

```vue
<script setup>
import { useWebSocket } from '@thelacanians/vue-native-runtime'

const { status, lastMessage, send, open, close } = useWebSocket('wss://echo.websocket.org', {
  autoConnect: true,
  autoReconnect: true
})
</script>

<template>
  <VView>
    <VText>Status: {{ status }}</VText>
    <VText>Last message: {{ lastMessage }}</VText>
    <VButton title="Send Hello" @press="send('Hello, server!')" />
    <VButton title="Disconnect" @press="close()" />
  </VView>
</template>
```

## API

```ts
useWebSocket(url: string, options?: WebSocketOptions): {
  status: Ref<WebSocketStatus>,
  lastMessage: Ref<string | null>,
  error: Ref<string | null>,
  send: (data: string | object) => void,
  close: (code?: number, reason?: string) => void,
  open: () => void
}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | `string` | The WebSocket server URL (must use `ws://` or `wss://`). |
| `options` | `WebSocketOptions` | Optional configuration for the connection. |

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `status` | `Ref<WebSocketStatus>` | The current connection status. |
| `lastMessage` | `Ref<string \| null>` | The most recently received message, or `null` if none. |
| `error` | `Ref<string \| null>` | The last error message, or `null` if no error. |
| `send` | `(data: string \| object) => void` | Send a message to the server. Objects are automatically JSON-stringified. |
| `close` | `(code?: number, reason?: string) => void` | Close the connection with an optional status code and reason. |
| `open` | `() => void` | Manually open or reopen the connection. |

### Types

```ts
interface WebSocketOptions {
  /** Whether to connect immediately on creation. Default: true */
  autoConnect?: boolean
  /** Whether to automatically reconnect on abnormal close. Default: false */
  autoReconnect?: boolean
  /** Maximum number of reconnection attempts. Default: 3 */
  maxReconnectAttempts?: number
  /** Delay between reconnection attempts in milliseconds. Default: 1000 */
  reconnectInterval?: number
}

type WebSocketStatus = 'CLOSED' | 'CONNECTING' | 'OPEN' | 'CLOSING'
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `URLSessionWebSocketTask` for native WebSocket connections with full TLS support. |
| Android | Uses OkHttp `WebSocket` for native WebSocket connections with full TLS support. |

## Example

```vue
<script setup>
import { ref, watch } from 'vue'
import { useWebSocket } from '@thelacanians/vue-native-runtime'

const messages = ref([])
const input = ref('')

const { status, lastMessage, send, error } = useWebSocket('wss://chat.example.com/ws', {
  autoConnect: true,
  autoReconnect: true,
  maxReconnectAttempts: 5,
  reconnectInterval: 2000
})

watch(lastMessage, (msg) => {
  if (msg) {
    messages.value.push(JSON.parse(msg))
  }
})

function sendMessage() {
  if (input.value.trim()) {
    send({ type: 'message', text: input.value })
    input.value = ''
  }
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VText :style="{ fontSize: 24, marginBottom: 8 }">Chat</VText>
    <VText :style="{ color: status === 'OPEN' ? 'green' : 'red', marginBottom: 16 }">
      {{ status }}
    </VText>

    <VScrollView :style="{ flex: 1, marginBottom: 16 }">
      <VText v-for="(msg, i) in messages" :key="i">{{ msg.text }}</VText>
    </VScrollView>

    <VText v-if="error" :style="{ color: 'red' }">{{ error }}</VText>

    <VView :style="{ flexDirection: 'row' }">
      <VInput v-model="input" placeholder="Type a message..." :style="{ flex: 1 }" />
      <VButton title="Send" @press="sendMessage" />
    </VView>
  </VView>
</template>
```

## Notes

- Objects passed to `send()` are automatically JSON-stringified before being sent over the connection.
- Auto-reconnect only triggers on abnormal close (i.e., close code is not `1000`). A clean close via `close()` or `close(1000)` will not trigger reconnection.
- Reconnection uses a fixed delay (`reconnectInterval`) between attempts, up to `maxReconnectAttempts`.
- If `autoConnect` is set to `false`, the connection will not open until `open()` is called manually.
- The connection is automatically closed and event listeners are unsubscribed when the component unmounts.
- The `status` ref transitions through `CONNECTING` -> `OPEN` -> `CLOSING` -> `CLOSED` following the standard WebSocket lifecycle.
