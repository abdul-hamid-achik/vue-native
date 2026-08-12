---
"@thelacanians/vue-native-runtime": patch
---

Composable cleanup and API-consistency fixes: `useDragDrop`/`useMenu` subscriptions are released automatically on unmount like the rest of the on* API, `useBluetooth` cancels active GATT characteristic subscriptions when the component unmounts (previously the peripheral kept notifying forever), `useSecureStorage` serializes writes per key exactly like `useAsyncStorage` (token refreshes from concurrent flows can no longer land out of order), `VFlatList` keys measured heights by `keyExtractor` identity so reordering/filtering data doesn't misplace variable-height items, and `VPicker` supports `v-model` (`modelValue`/`update:modelValue`) with the legacy `value`/`change` pair kept as a working alias.
