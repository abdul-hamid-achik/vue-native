---
"@thelacanians/vue-native-runtime": minor
"@thelacanians/vue-native-vite-plugin": minor
"@thelacanians/vue-native-cli": minor
---

Hot-reload authentication for network-exposed dev servers.

- The Vite plugin now embeds a persisted hot-reload token into the bundle (`__HOT_RELOAD_TOKEN__`, stored under `node_modules/.vue-native/hot-reload-token`), and the runtime exposes it as a global so the native hot-reload client can present it.
- `vue-native dev --lan` now requires that token: LAN clients must present a valid `?token=` on the WebSocket connection or they are rejected, so a rogue client on your network cannot inject a bundle. Loopback connections (simulators/emulators) are unaffected and the default localhost-only binding is unchanged.
- iOS, Android, and macOS read the token from the loaded bundle and include it when connecting/reconnecting (ships with the tag).
