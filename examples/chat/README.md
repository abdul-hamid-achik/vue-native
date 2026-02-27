# Chat

A real-time chat app using WebSockets with an echo server.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput, VScrollView, VKeyboardAvoiding
- **Composables:** `useWebSocket` (real-time messaging)
- **Patterns:** `watch` for incoming messages, computed status indicators, keyboard avoidance

## Key Features

- Real-time messaging via WebSocket echo server
- Connection status indicator (connected / connecting / disconnected)
- Auto-reconnect with configurable retry logic
- Message bubbles with timestamps (sent vs received)
- Keyboard-avoiding input bar
- Reconnect button on connection loss

## How to Run

```bash
bun install
bun run dev
```
