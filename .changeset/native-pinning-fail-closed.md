---
'@thelacanians/vue-native-cli': patch
---

Certificate pinning no longer fails open on a malformed first configuration.

A host whose first pin list is entirely malformed was left unpinned without an
error. It is now refused until a valid pin is configured; an empty list still
unpins the host, and a malformed update keeps the previous valid pins. On
Android only `sha256/` pins are valid, as on Apple.
