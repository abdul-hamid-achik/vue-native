---
"@thelacanians/vue-native-runtime": patch
---

Keep native WebSocket lifecycle events bound to the socket that created them,
suppress stale callbacks after same-ID reconnects, and emit terminal events
exactly once. Apple connections now share a serialized URLSession state
machine and report `open` only after the WebSocket handshake succeeds.
