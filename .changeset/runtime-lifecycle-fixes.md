---
"@thelacanians/vue-native-runtime": patch
---

Fix node-lifecycle leaks and broken built-ins in the renderer and bridge: removed nodes now release their event-handler closures (previously leaked for the app's lifetime), multiple subscribers can share one (node, event) listener so a manual gesture `on()` no longer silently knocks out the declarative binding, handler-identity changes swap in place without bridge traffic, `v-model` writes through the latest binding after re-renders, `<KeepAlive>` actually detaches deactivated subtrees natively, `<Teleport to="modal|root">` now mounts (querySelector was missing, content was silently dropped), and `useDatabase` refcounts shared connections so one unmount cannot close a database another component is using.
